require 'google/reader'
require 'json'
require 'nokogiri'

class GReadie
  READING_LIST_URL = "http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/reading-list"
  UNREAD_LIST_URL  = READING_LIST_URL + "?xt=user/-/state/com.google/read" #presently not used

	def initialize(in_username, in_password)
		@username = in_username
		@password = in_password
	end

	def reading_list(number_to_fetch = 20, continuation = nil)
	  response = json_reading_list({:n => number_to_fetch, :c => continuation})
	  list = response['items'].collect do |item_hash|
      GReadie::Entry.new(item_hash)
    end
    [list, response['continuation']]
	end

protected
  def connect!
	  @connection ||= Google::Reader::Base.establish_connection @username, @password
	end
	
	def fetch(url, options)
	  raise "No url provided" unless url
	  raise "Couldn't connect to Google Reader" unless connect!
	  Google::Reader::Base.get url, options
	end
	
	def json_reading_list(options = {})
	  url = "#{READING_LIST_URL}"
	  JSON.parse(fetch(url, :query_hash => options))
	end
end

class GReadie::Entry
  attr_reader :title, :author, :href, :google_item_id, :feed, :categories, :body
  
  def initialize(item)
    
    @title = normalize item['title'] 
    @author = normalize item['author'] 
    @href = item['alternate'].first['href']
    @google_item_id = item['id']
    @published = item['published']
    @updated = item['updated']
    @body = normalize get_body(item)
    @feed = GReadie::Feed.new(item['origin'])
  end
  
  def published_at
    Time.new @published
  end
  
  def updated_at
    Time.new @updated
  end
  
  def body=(text)
    # parse body text into tag collections
    # isolate paragraphs, blockquotes, and images
    # grab first three paragraphs
    # take word count of these paragraphs, find cutoff point
    # close tags and return
  end
  
protected

  def get_body(item_hash)
    container = item_hash['content'] || item_hash['summary']
    return container['content']
  rescue
    nil
  end
  
  def normalize(text)
    return text if text.nil?
    Nokogiri::XML::DocumentFragment.parse(text).to_html
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