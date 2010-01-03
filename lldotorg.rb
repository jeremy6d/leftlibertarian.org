require 'greadie'
require 'nokogiri'
require 'activesupport'
require 'haml'
require 'sass'
require 'ftools'

class LLDotOrg  
  MAX_BODY_LENGTH = 1000
  PARAGRAPH_DELIMITER_REGEXP = /(<br>|<p>|<\/p>|\n)/
  
  def initialize(environment = "development", options = {})
    creds = YAML.load(File.open('config/credentials.yml'))
    establish_connection! creds[environment]['username'], 
                          creds[environment]['password']
  end
	
	def error_pages(target_dir)
    ["404","5xx"].each do |err|
      File.open("#{target_dir}/#{err}.html", "w") do |f|
        f.write Haml::Engine.new(File.read("templates/#{err}.haml")).render
      end
    end
	end
	
	def entries
	  @normalized_entries
  end
	
	def generate(save_to_path, limit = 999999)
	  raw_list = @conn.reading_list(limit).first
	  
	  html_list = raw_list.collect do |item| 
	    render_haml 'feed_item', { :entry => item,
	                               :content => truncate_body(item, MAX_BODY_LENGTH) }
    end
	  

	  render_css
	  copy_images
	  log raw_list.size
	end
	
	def establish_connection!(username, password)
	  @conn = GReadie.new username, password
	end
	
	def update!(continuation = nil)
	  @last_continuation = @continuation
	  entries, @continuation = @conn.reading_list(initial_entry_count, continuation)
	  @normalized_entries = entries.collect do |item|
	    render_haml 'feed_item', { :entry => item,
	                               :content => truncate_body(item, MAX_BODY_LENGTH) }
	  end
	end
	
	def paginate_all_entries(save_to_path, entries_per_page)
	  html_list = @normalized_entries.clone
	  
	  page_number = 1
	  
	  path = File.expand_path(save_to_path)
	  
	  until html_list.empty?
	    generate_page(path, :page_number => page_number)
	    page_number = page_number + 1
	  end
	  true
	rescue
	  false
	end
	
	def generate_page(pages_root_path, navigation)
	  file_name = ( options[:page_number] == 1) ? "index" : page_number.to_s
    file_to_write = File.join path, "#{file_name}.html"
    @haml_engine = Haml::Engine.new(File.read('templates/feed_list.haml'))
    
    File.open file_to_write, "w" do |f|
      prev_pg = case page_number
      when 1
        nil
      when 2
        "index"
      else
        page_number - 1
      end
	  
	    html = haml_engine.render Object.new, :list => html_list.slice!(0, 20),
                                            :next_page_no => (html_list.empty? ? nil : (page_number + 1)),
                                            :prev_page_no => prev_pg

      f.write apply_layout(title(page_number), html)
	end
	
	def truncate_body(entry, char_count = 2000)
    doc = Nokogiri::XML::DocumentFragment.parse(entry.body)
    count = index = 0
    truncated = false
    
    doc.children.each do |child|
      count = count + child.content.length.to_i
      index = index + 1
      if count > char_count
        truncated = true
        break
      end
    end

    normalized_content = doc.children.slice(0, index).to_html

    if truncated
      normalized_content << "<div class=\"read_more\"><a href='#{entry.href}'>(read more)</a></div>" 
    end
    
    normalized_content
  rescue
    "<p>PARSING ERROR! Jeremy sucks.</p>"
	end
	
	def title(page_no)
	  subtitle = "Page #{page_no}" if (page_no && (page_no > 1))
	  ["leftlibertarian.org", subtitle].compact.join(" - ")
	end
	
	def render_css
	  puts "generating stylesheet..."
	  engine = Sass::Engine.new(File.read('templates/style.sass'))
	  File.open "public/style.css", "w" do |f|
      f.write engine.render
    end
	end
	
	def apply_layout(title, content)
	  render_haml "layout", {:content => content, :title => title, :tracking_code => tracking_code}
	end
	
	def render_haml(template_file_name, data_hash = {})
	  template_markup = File.read("templates/#{template_file_name}.haml")
	  engine = Haml::Engine.new(template_markup)
	  engine.render(Object.new, data_hash)
	end
	
	def generate_pages
	  Dir.new("pages").entries.select { |n| /\.haml/.match n }.each do |page_name|
	    page_title = page_name.split(".").first
	    File.open("public/#{page_title}.html", "w") do |f|
	      page_content = Haml::Engine.new(File.read("pages/#{page_name}")).render
	      f.write apply_layout("#{page_title.titleize} leftlibertarian.org", page_content)
	    end
	  end
	end
	
	def copy_images
	  pwd = Dir.pwd
	  images_src = "#{pwd}/images"
	  images_dest = "#{pwd}/public/images"
	  
	  Dir.mkdir(images_dest) unless test(?d, images_dest)
	  
	  Dir.open(images_src).entries.each do |img_filename|
	    next unless /\.(jpg|gif|png|bmp)/.match img_filename
	    puts img_filename
	    File.copy "#{images_src}/#{img_filename}", "#{images_dest}/#{img_filename}", true
	  end
	end
	
	def log(entry_count)
	  File.open("generation.log", "a") do |f|
	    f.write "\n* Generated site at #{Time.now}, entries = #{entry_count}"
	  end
	end
	
	def tracking_code
	  File.read("templates/analytics_code.html")
	end
	
	
	def call(env)
	  # parse continuation in request uri
    tokens = /continue\/(\w+)/.match env['PATH_INFO']
    continuation = tokens.captures.first unless tokens.nil?
    
    # refresh data
    list, continuation = @conn.reading_list(20, continuation)
    
    page = get_html(list.collect { |item| list_item(item) }, continuation)
	  
	  [ 200, {}, page ]
	end
end