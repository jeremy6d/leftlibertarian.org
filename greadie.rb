require 'google/reader'
require 'JSON'

class GReadie
  READING_LIST_URL = "http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/reading-list"
  UNREAD_LIST_URL  = READING_LIST_URL + "?xt=user/-/state/com.google/read"

	def initialize(in_username, in_password)
		@username = in_username
		@password = in_password
	end

	def reading_list
	  json_reading_list.collect do |item_hash|
      GReadie::Entry.new(item_hash)
    end
	end

protected
  def connect!
	  @connection ||= Google::Reader::Base.establish_connection @username, @password
	end
	
	def fetch(url)
	  raise "No url provided" unless url
	  raise "Couldn't connect to Google Reader" unless connect!
	  Google::Reader::Base.get url
	end
	
	def json_reading_list
	  JSON.parse(fetch(READING_LIST_URL))['items']
	end
end

class GReadie::Entry
  attr_reader :title, :author, :href, :google_item_id, :feed, :categories, :body
  
  def initialize(item)
    @title = item['title']
    @author = item['author']
    @href = item['alternate'].first['href']
    @google_item_id = item['id']
    @published = item['published']
    @updated = item['updated']
    @body = item['content']["content"]
    @feed = GReadie::Feed.new(item['origin'])
  end
  
  def published_at
    Time.new @published
  end
  
  def updated_at
    Time.new @updated
  end
  
  def to_li
    "<li class='entry' id='#{@google_item_id}'>
        <h2><a href='#{@href}'>#{@title}</a></h2>
        <p>#{@body}</p>
     </li>"
  end
end

class GReadie::Feed
  attr_reader :google_feed_id, :title, :href
  
  def initialize(options)
    @title = options['title']
    @href = options['htmlUrl']
    @google_feed_id = options['streamId']
  end
end