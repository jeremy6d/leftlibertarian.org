require 'greadie'
require 'nokogiri'
require 'activesupport'
require 'haml'
require 'sass'
require 'ftools'

class LLDotOrg  
  MAX_BODY_LENGTH = 1000
  PARAGRAPH_DELIMITER_REGEXP = /(<br>|<p>|<\/p>|\n)/
  
  def initialize(environment = "development")
    creds = YAML.load(File.open('config/credentials.yml'))
    @conn = LLDotOrg.establish_connection creds[environment]['username'], creds[environment]['password']
  end
  
	def call(env)	  
    tokens = /continue\/(\w+)/.match env['PATH_INFO']
    continuation = tokens.captures.first unless tokens.nil?
    
    list, continuation = @conn.reading_list(20, continuation)
    
    page = get_html(list.collect { |item| list_item(item) }, continuation)
	  
	  [ 200, {}, page ]
	end
	
	def error_pages(target_dir)
    ["404","5xx"].each do |err|
      File.open("#{target_dir}/#{err}.html", "w") do |f|
        f.write Haml::Engine.new(File.read("templates/#{err}.haml")).render
      end
    end
	end
	
	def generate(save_to_path, limit = 999999)
	  raw_list = @conn.reading_list(limit).first
	  
	  html_list = raw_list.collect do |item| 
	    render_haml 'feed_item', { :entry => item,
	                               :content => truncate_body(item, MAX_BODY_LENGTH) }
    end
	  
	  page_number = 1
	  
	  path = File.expand_path(save_to_path)
	  
	  until html_list.empty?
	    file_name = (page_number == 1) ? "index" : page_number.to_s
	    file_to_write = File.join path, "#{file_name}.html"
      haml_engine = Haml::Engine.new(File.read('templates/feed_list.haml'))

	    File.open file_to_write, "w" do |f|
	      prev_pg = case page_number
        when 1
          nil
        when 2
          "index"
        else
          page_number - 1
        end

        text = haml_engine.render(Object.new, :list => html_list.slice!(0, 20),
                                              :next_page_no => (html_list.empty? ? nil : (page_number + 1)),
                                              :prev_page_no => prev_pg) 

        f.write apply_layout(title(page_number), text)
	    end

	    page_number = page_number + 1
	  end
	  generate_pages
	  render_css
	  copy_images
	  log raw_list.size
	end
	
	def self.establish_connection(username, password)
	  GReadie.new username, password
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
	
	# TODO: close tags
	# TODO: crazy character support
	def massage(item)
	  paragraphs = get_paragraphs(item.body)
	  len = 0
	  final_para_len = nil
	  final_index = 0
	  paragraphs.each_with_index do |p,i|
	    final_index = i
	    if (len + p.length) > MAX_BODY_LENGTH
	      final_para_len = MAX_BODY_LENGTH - len
	      break
	    end
	    len = len + p.length
	  end

	  unless final_para_len.nil? || (final_index >= paragraphs.size)
	    paragraphs[final_index] = paragraphs[final_index][0..final_para_len]
	    paragraphs[final_index] << "<span class='read-more'>... <a href='#{item.href}'>(read more)</a></span>"
	  end
	  
	  paragraphs[0..((final_index < 2) ? final_index : 2)].collect { |p| "<p>#{p}</p>" }.join
	end
	
	def get_paragraphs(content)
    content.split(PARAGRAPH_DELIMITER_REGEXP).reject { |p| p.nil? || p == "" || PARAGRAPH_DELIMITER_REGEXP.match(p) }.compact
	end
	
	def get_continuation_html(list, continuation = nil)
	  [%q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
            <meta http-equiv="Content-Type" content="application/xhtml+xml" charset="utf-8" />
            <title>leftlibertarian.org</title>
            <!-- link rel="shortcut icon" href="" / -->
            <meta name="keywords" content="anarchy, anarchism, left libertarianism, market anarchism" />
            <meta name="description" content="Left libertarian content from around the web..." />
            <meta name="author" content="Jeremy Weiland" />
            <meta name="ROBOTS" content="ALL" />
        </head>
    	  <body>
      	  <h1>leftlibertarian.org</h1>
      	  <span class="slogan">Left libertarian views from around the web...</span>
          <ul> }, list, %q{</ul>}, "<div><a href='/continue/#{continuation}'>Next page</a></div>", %q{
        </body>
      </html> }].join
	end
	
	def generate_saved_html(list, page_no, next_page_no)
	  [%q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
            <meta http-equiv="Content-Type" content="application/xhtml+xml" charset="utf-8" />
            <title>leftlibertarian.org}, (" - Page #{page_no}" if (page_no && (page_no > 1))), %q{</title>
            <link type="text/css" rel="stylesheet" href="/style.css">
            
            <meta name="keywords" content="anarchy, anarchism, left libertarianism, market anarchism" />
            <meta name="description" content="Left libertarian content from around the web..." />
            <meta name="author" content="Jeremy Weiland" />
            <meta name="ROBOTS" content="ALL" />
        </head>
    	  <body>
      	  <h1>leftlibertarian.org</h1>
      	  <span class="slogan">Left libertarian views from around the web...</span>
          <ul> }, list, %q{</ul>}, ("<div><a href='/pages/#{next_page_no}'>Next page</a></div>" if next_page_no), %q{
        </body>
      </html> }].compact.join
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
	  %q{<script type="text/javascript">
    var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
    document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
    </script>
    <script type="text/javascript">
    try {
    var pageTracker = _gat._getTracker("UA-3295516-1");
    pageTracker._trackPageview();
    } catch(err) {}</script>}
	end
end