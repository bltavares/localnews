require "bundler/setup"
require "sinatra"
require "feedzirra"
require "redis"
require "json"
require "nokogiri"
require 'digest/md5'
require "hiredis"


A_MONTH_IN_SECONDS = 2.62974e6

class App < Sinatra::Base

  uri = URI.parse(ENV["REDISTOGO_URL"] || "http://localhost:6379")
  redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :driver => :hiredis)

  enable :static
  set :environment, :production

  before do
    content_type 'application/json'
  end

  def early_than_a_month(i)
    current_time = Time.now.to_i
    (current_time - i) <= A_MONTH_IN_SECONDS
  end

  def subscriptions(redis)
    redis.smembers("subscriptions")
  end

  def normalize_url(url)
    url.chomp.strip.downcase.gsub(/\/$/, "")
  end

  def mark_as_read(redis, key)
    entry = Hash[JSON.parse(redis.hget("news", key))]
    redis.multi do
      redis.zadd "read", DateTime.parse(entry["published"].to_s).to_i , key
      redis.zrem "unread", key
    end
    entry
  end

  def mark_as_unread(redis, key)
    entry = Hash[JSON.parse(redis.hget("news", key))]
    redis.multi do
      redis.zadd "unread", DateTime.parse(entry["published"].to_s).to_i , key
      redis.zrem "read", key
    end
    entry
  end

  get '/subscriptions' do
    subscriptions(redis).to_json
  end

  delete '/subscriptions' do
    redis.srem("subscriptions", params[:url])
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

  post '/unread' do
    redis.multi do
      redis.zunionstore "read", ["unread", "read"]
      redis.del "unread"
    end
    redirect "/"
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
    mark_as_read(redis, key).to_json
  end

  put '/news/:id' do
    key = params[:id]
    if params["state"] == "read"
      mark_as_read(redis, key).to_json
    else
      mark_as_unread(redis, key).to_json
    end
  end

  get '/refresh' do
    subscriptions(redis).each do |url|
      feed  = Feedzirra::Feed.fetch_and_parse(url)
      if feed.nil? or feed.is_a? Fixnum
        logger.error "Bad feed url: " + url
        next
      end

      feed.entries.each do |entry| 
        published = entry.published.to_i
        if early_than_a_month(published)
          key = Digest::MD5.hexdigest(entry.url.to_s)
          read = redis.zscore "read", key
          redis.zadd "unread", published, key unless read
          redis.hsetnx "titles", key, entry.title
          redis.hsetnx "news", key, entry.to_json
        end
      end
    end
    redirect "/"
  end

  get '/cleanup' do
    time = Time.now.to_i
    past = time - A_MONTH_IN_SECONDS
    read_entries = redis.zrangebyscore("read", "-inf", past)
    unless read_entries.empty?
      redis.multi do
        redis.hdel("news", read_entries)
        redis.hdel("titles", read_entries)
        redis.zremrangebyscore("read", "-inf", past)
      end
    end
  end

  get '/'do
    content_type 'text/html'
    File.read(File.join('public', 'index.html'))
  end
end
