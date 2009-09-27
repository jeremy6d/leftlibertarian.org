require 'greadie'

class LLDotOrg
  GOOGLE_USERNAME = "leftlibertarian.org"
  GOOGLE_PASSWORD = "nu7og9pewm6ayd7wi4tef7hat3gag4niel1"
  MAX_BODY_LENGTH = 1250
  PARAGRAPH_DELIMITER_REGEXP = /(<br>|<p>|<\/p>|\n)/
  
	def call(env)
	  conn = establish_connection
	  
    tokens = /continue\/(\w+)/.match env['PATH_INFO']
    continuation = tokens.captures.first unless tokens.nil?
    
    list, continuation = conn.reading_list(continuation)
    
    page = get_html(list.collect { |item| list_item(item) }, continuation)
	  
	  [ 200, {}, page ]
	end
	
	def generate
	  conn = establish_connection
	  
	  list = conn.reading_list.collect { |item| list_item(item) }
	end
	
	def establish_connection
	  GReadie.new GOOGLE_USERNAME, GOOGLE_PASSWORD
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
	
	def get_html(list, continuation = nil)
	  [%q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
            <meta http-equiv="Content-Type" content="application/xhtml+xml" charset=utf-8" />
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
end