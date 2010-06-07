require 'greadie'
require 'nokogiri'
require 'active_support'
require 'haml'
require 'sass'
require 'ftools'
require 'builder'
require 'ruby-debug'

class LLDotOrgHelper
  attr_reader :title
  def set_title(title)
    @title = title
  end
end

class LLDotOrg
   
  MAX_BODY_LENGTH = 1000
  DEFAULT_OUTPUT_DIR = "public"
  DEFAULT_PER_PAGE = 20
  LIST_TEMPLATE = "feed_list"
  ITEM_TEMPLATE = "feed_item"
  SHARE_POST_LIMIT = DEFAULT_PER_PAGE
  
  def initialize(environment = "development", save_to_path = nil)
    @credentials ||= YAML.load(File.open('config/credentials.yml'))[environment]
    @output_path = save_to_path || File.expand_path(DEFAULT_OUTPUT_DIR)
    @connection = GReadie.new @credentials['username'], @credentials['password']
  end
	
	def generate_site!
	  raise "No connection established" unless @connection
    entry_count = update_entry_list!
    paginate_entry_list!
	  generate_css!
	  generate_static_pages!
	  generate_error_pages!
	  copy_images!
	  bulk_share!
	  log!(entry_count)
	end
	
	def bulk_share!(limit = SHARE_POST_LIMIT)
	  @greadie_entries[0..limit].each do |e|
	    @connection.share! e
	  end
	end
	
	def update_entry_list!(number_to_fetch = 99999)
	  @greadie_entries = @connection.reading_list(number_to_fetch).first
	  filter_entries!
	  @normalized_entries = @greadie_entries.sort do |i,j| 
	    j.sort_by_time <=> i.sort_by_time 
	  end.collect do |item|
      puts item.inspect
	    render_haml ITEM_TEMPLATE, { :entry => item,
	                                 :content => truncate_body(item, MAX_BODY_LENGTH) }
	  end
	  @normalized_entries.size
	end
	
	def filter_entries!
	  @greadie_entries.delete_if { |entry| entry.title.include? "At C4SS" }
	  remove_duplicates!
	end
	
	def remove_duplicates!
	  url_list = []
	  @greadie_entries.delete_if do |entry|
	    duplicate = url_list.include? entry.href
	    url_list << entry.href
	    duplicate
	  end
	end
	
	def entry_list
	  update_entry_list! unless @normalized_entries
	  @normalized_entries
	end
	
	def generate_css!
	  puts "generating stylesheet..."
	  engine = Sass::Engine.new(File.read('templates/style.sass'))
	  File.open "public/style.css", "w" do |f|
      f.write engine.render
    end
	end
	
	def generate_static_pages!
	  Dir.new("pages").entries.select { |n| /\.haml/.match n }.each do |page_name|
	    page_title = page_name.split(".").first
	    File.open("public/#{page_title}.html", "w") do |f|
	      page_content = Haml::Engine.new(File.read("pages/#{page_name}")).render(h = LLDotOrgHelper.new)
	      f.write apply_layout("#{h.title || page_title.titleize} | leftlibertarian.org", page_content)
	    end
	  end
	end
	
	def copy_images!
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
	
	def generate_error_pages!(target_dir = "error")
    ["404","5xx"].each do |err|
      File.open("#{target_dir}/#{err}.html", "w") do |f|
        f.write Haml::Engine.new(File.read("templates/#{err}.haml")).render
      end
    end
	end
	
	def paginate_entry_list!(entries_per_page = DEFAULT_PER_PAGE)
	  html_list = @normalized_entries.clone
	  page_number = 1
	  
	  until html_list.empty?
	    file_name = (page_number == 1) ? "index" : page_number.to_s
      file_to_write = File.join @output_path, "#{file_name}.html"

      File.open file_to_write, "w" do |f|
        prev_pg = case page_number
        when 1
          nil
        when 2
          "index"
        else
          page_number - 1
        end

  	    html = render_haml LIST_TEMPLATE, :list => html_list.slice!(0, DEFAULT_PER_PAGE),
                                          :next_page_no => (html_list.empty? ? nil : (page_number + 1)),
                                          :prev_page_no => prev_pg

        f.write apply_layout(title(page_number), html)
      end
	    page_number = page_number + 1
	  end
	end
	
	def raw_entries
	  @greadie_entries
	end
	
protected	
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
	
	def apply_layout(title, content)
	  render_haml "layout", :content => content, 
	                        :title => title, 
	                        :tracking_code => tracking_code
	end
	
	def render_haml(template_name, data_hash = {})
	  raise "No template" unless template_name
	  template_path = "templates/#{template_name}.haml"
	  template_markup = File.read(template_path)
	  engine = Haml::Engine.new(template_markup)
	  engine.render(Object.new, data_hash)
	end
	
	def log!(entry_count)
	  File.open("generation.log", "a") do |f|
	    f.write "\n* Generated site at #{Time.now}, entries = #{entry_count}"
	  end
	end
	
	def tracking_code
	  File.read("templates/analytics_code.html")
	end
	
	
	def atom_id(url, publish_date)
	  formatted_date = Time.parse(publish_date).strftime(",%Y-%m-%d:")
	  segments = url.gsub("http://", "tag:").split("/")
	  segments.first << formatted_date
	  segments.join("/")
	end
end