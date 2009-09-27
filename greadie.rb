require 'google/reader'
require 'json'

class GReadie
  READING_LIST_URL = "http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/reading-list"
  UNREAD_LIST_URL  = READING_LIST_URL + "?xt=user/-/state/com.google/read"

	def initialize(in_username, in_password)
		@username = in_username
		@password = in_password
	end

	def reading_list(continuation = nil)
	  response = json_reading_list(continuation)
	  list = response['items'].collect do |item_hash|
      GReadie::Entry.new(item_hash)
    end
    [list, response['continuation']]
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
	
	def json_reading_list(continuation_token = nil)
	  querystring = "?c=#{continuation_token}" if continuation_token
	  url = "#{READING_LIST_URL}#{querystring}"
	  JSON.parse(fetch(url))
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
    @body = get_body(item)
    @feed = GReadie::Feed.new(item['origin'])
  end
  
  def published_at
    Time.new @published
  end
  
  def updated_at
    Time.new @updated
  end
  
protected

  def get_body(item_hash)
    container = item_hash['content'] || item_hash['summary']
    return container['content']
  rescue
    nil
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