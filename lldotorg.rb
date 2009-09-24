require 'greadie'

class LLDotOrg
  GOOGLE_USERNAME = "leftlibertarian.org"
  GOOGLE_PASSWORD = "nu7og9pewm6ayd7wi4tef7hat3gag4niel1"
  MAX_BODY_LENGTH = 1250
  
	def call(env)
	  conn = establish_connection
	  
    list = conn.reading_list.collect { |item| list_item(item) }
	  
	  [ 200, {}, get_html(list) ]
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
	
	def massage(item)
	  paragraphs = item.body.split("<br><br>").compact
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

	  unless final_para_len.nil?
	    paragraphs[final_index] = paragraphs[final_index][0..final_para_len]
	    paragraphs[final_index] << "..."
	  end
	  
	  final_body = paragraphs[0..final_index].collect { |p| "<p>#{p}</p>" }.join
    
    unless final_para_len.nil?
      final_body << "<p class='read-more'><a href='#{item.href}'>Read more...</a></p>" 
    end
    
    final_body
	end
	
	def truncate(content)
	  return content unless content.length > MAX_BODY_LENGTH
	  
	end
	
	def get_html(list)
	  [%q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
            <title>leftlibertarian.org</title>
            <!-- link rel="shortcut icon" href="" / -->
            <meta name="keywords" content="anarchy, anarchism, left libertarianism, market anarchism" />
            <meta name="description" content="Left libertarian content from around the web..." />
            <meta name="author" content="Jeremy Weiland" />
            <meta name="ROBOTS" content="ALL" />
        </head>
    	  <body>
      	  <h1>leftlibertarian.org</h1>
          <ul> }, list, %q{</ul>
        </body>
      </html> }].join
	end
end