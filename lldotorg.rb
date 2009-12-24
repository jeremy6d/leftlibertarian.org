require 'greadie'

class LLDotOrg  
  MAX_BODY_LENGTH = 1250
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
	
	def generate(save_to_path)
	  raw_list = @conn.reading_list(999999).first
	  
	  puts raw_list.size
	  
	  html_list = raw_list.collect { |item| list_item(item) }
	  
	  page_number = 1
	  
	  path = File.expand_path(save_to_path)
	  
	  until html_list.empty?
	    file_to_write = File.join path, "#{page_number}.html"
	    File.open file_to_write, "w" do |f|
	      page_entries = html_list.slice!(0, 20)
	      next_page_number = page_number + 1 unless html_list.empty?
	      f.write generate_saved_html(page_entries, page_number, next_page_number)
	    end
	    page_number = page_number + 1
	  end
	end
	
	def self.establish_connection(username, password)
	  GReadie.new username, password
	end
	
	def list_item(entry)
	  "<li class='entry' id='#{entry.google_item_id}'>
        <h2><a href='#{entry.href}'>#{entry.title}</a> <small>#{entry.author} at <a href='#{entry.feed.href}'>#{entry.feed.title}</a></small></h2>
        #{massage(entry)}
     </li>"
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
            <meta http-equiv="Content-Type" content="application/xhtml+xml" charset=utf-8" />
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
end