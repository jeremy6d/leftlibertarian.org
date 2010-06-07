require 'google/reader'
require 'ruby-debug'
require 'active_support'
require 'nokogiri'

class GReadie
  BASE_URL = "http://www.google.com/reader/api/0/"
  READING_LIST_URL = BASE_URL + "stream/contents/user/-/state/com.google/reading-list"
  UNREAD_LIST_URL  = READING_LIST_URL + "?xt=user/-/state/com.google/read" #presently not used
  EDIT_TAG_URL = BASE_URL + "edit-tag"

	def initialize(in_username, in_password)
		@username = in_username
		@password = in_password
	end

	def reading_list(number_to_fetch = 20, continuation = nil)
	  response = json_reading_list({:n => number_to_fetch, :c => continuation})
	  list = response['items'].collect do |item_hash|
      GReadie::Entry.new(item_hash) rescue nil
    end.compact
    [list, response['continuation']]
	end
	
	def token
	  @token || reset_token!
	end
	
	def reset_token!
	  @token = Google::Reader::Base.get_token
	end
	
	def share!(entry)
	  Google::Reader::Base.post GReadie::EDIT_TAG_URL, :form_data => {
      :T => token,
      :a => Google::Reader::State::BROADCAST, 
      :async => false,
      :i => entry.google_item_id,
      :s => entry.feed.google_feed_id
    }
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
    # JSON.parse(fetch(url, :query_hash => options))
    json_document = fetch(url, :query_hash => options)
    ActiveSupport::JSON.decode json_document
	end
end

class GReadie::Entry
  attr_reader :title, :author, :href, :google_item_id, :feed, :categories, :body
  
  def initialize(item)
    raise "Title is nil" unless item['title']
    @title = normalize item['title']
    @author = normalize item['author'] 
    @href = item['alternate'].first['href']
    @google_item_id = item['id']
    @published = item['published']
    @updated = item['updated']
    @body = normalize get_body(item)
    @feed = GReadie::Feed.new(item['origin'])
  end
  
  def sort_by_time
    updated_at || published_at
  end
  
  def published_at
    Time.at @published rescue nil
  end
  
  def updated_at
    Time.at @updated rescue nil
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
    container = item_hash['content'] || item_hash['summary'] || item_hash['description']
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