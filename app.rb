require "bundler/setup"
require "sinatra"
require "feedzirra"
require "redis"
require "json"
require "nokogiri"
require 'digest/md5'

class App < Sinatra::Base

  uri = URI.parse(ENV["REDISTOGO_URL"] || "http://localhost:6379")
  redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  enable :static
  set :environment, :production

  before do
    content_type 'application/json'
  end

  def subscriptions(redis)
    redis.smembers("subscriptions")
  end

  def normalize_url(url)
    url.chomp.strip.downcase.gsub(/\/$/, "")
  end

  get '/subscriptions' do
    subscriptions(redis).to_json
  end

  post '/subscriptions' do
    redis.sadd("subscriptions", normalize_url(params[:url]))
    redirect "/"
  end

  post '/import' do
    doc = Nokogiri.XML(params['import'][:tempfile].read)
    redis.sadd("subscriptions", doc.xpath("//outline/@xmlUrl").map(&:value))
    redirect "/refresh"
  end


  get '/unread' do
    redis.zcard("unread").to_json
  end

  get '/news/unread' do
    unread_keys = redis.zrange("unread", 0, -1)
    if unread_keys.empty?
      []
    else
      titles = redis.hmget("titles", *unread_keys)
      Hash[unread_keys.zip(titles)]
    end.to_json
  end

  get '/news/:id' do
    key = params[:id]
    entry = Hash[JSON.parse(redis.hget("news", key))]
    redis.multi do
      redis.zadd "read", DateTime.parse(entry["published"].to_s).to_i , key
      redis.zrem "unread", key
    end
    entry.to_json
  end

  get '/refresh' do
    subscriptions(redis).each do |url|
      feed  = Feedzirra::Feed.fetch_and_parse(url)
      if feed.nil? or feed.is_a? Fixnum
        logger.error "Bad feed url: " + url
        next
      end

      feed.entries.each do |entry| 
        key = Digest::MD5.hexdigest(entry.url.to_s)
        read = redis.zscore "read", key
        redis.zadd "unread", entry.published.to_i, key unless read
        redis.hsetnx "titles", key, entry.title
        redis.hsetnx "news", key, entry.to_json
      end
    end
    redirect "/"
  end

  get '/'do
    content_type 'text/html'
    File.read(File.join('public', 'index.html'))
  end
end
