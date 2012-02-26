require 'rubygems'
require 'bundler/setup'
require 'rubygems'
require 'tweetstream'
require 'json'
require 'redis'
require 'geokit'
require 'nestful'
require 'ruby-debug'

# if ENV['RACK_ENV'] == 'development'
#   require File.expand_path(Dir::pwd + '/tweet_store', __FILE__)
# else
  require File.expand_path(ENV['APP_ROOT']+'/tweet_store', __FILE__)
# end


class TweetStream::Daemon
  def start(path, query_parameters = {}, &block) #:nodoc:
    # Because of a change in Ruvy 1.8.7 patchlevel 249, you cannot call anymore
    # super inside a block. So I assign to a variable the base class method before
    # the Daemons block begins.
    startmethod = super.start
    Daemons.run_proc(@app_name || 'tweetstream', :multiple => true, :no_pidfiles => true) do
      startmethod(path, query_parameters, &block)
    end
  end
end

  TweetStream.configure do |config|
    config.consumer_key = ENV['TWITTER_KEY']
    config.consumer_secret = ENV['TWITTER_SECRET']
    config.oauth_token = ENV['TWITTER_OAUTH_TOKEN']
    config.oauth_token_secret = ENV['TWITTER_OAUTH_SECRET']
    config.auth_method = :oauth
    config.parser   = :yajl
  end

  Geokit::default_units = :miles
  Geokit::default_formula = :sphere

  STORE = TweetStore.new
  if ENV["REDISTOGO_URL"]
    uri = URI.parse(ENV["REDISTOGO_URL"])
    redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    redis = Redis.new
  end

  REDIS_KEY = 'tweets'

  CURRENT_POSITION = "40.735726, -73.99507"


  #TweetStream::Client
  TweetStream::Daemon.new(ENV['TWITTER_USERNAME'], ENV['TWITTER_PASSWORD']).on_error do |message|
    puts message
  end.track('twinderella') do |status, client|
    if status.key?(:entities) && status.entities.key?(:media) && status.entities.media.first["type"] == "photo" #&& status.key?(:geo) && status.geo != nil && status.geo.key?(:coordinates)
      # c = status.geo.coordinates
      # unless c.length > 1
      #   c = c.join(', ')
      # end

      #if Geokit::LatLng.distance_between(CURRENT_POSITION, c).to_i < 500
        redis.lpush(REDIS_KEY, {

          'id' => status[:id],
          'text' => status.text,

          'username' => status.user.screen_name,
          'photo_url' => status.entities.media.first['media_url'],
          'userid' => status.user[:id],
          'name' => status.user.name,
          'profile_image_url' => status.user.profile_image_url,
          'received_at' => Time.new.to_i

        }.to_json)

        tweet_url = status.entities.media.first['url']
        photo_url = status.entities.media.first['media_url']
        tweet_id = status[:id]
        tweet_text = status.text
        received_at = Time.new.to_i
        Nestful.post '107.20.208.47:3000/', :format => :json, :params => {:photo => photo_url, :tweet => tweet_url, :tweet_t => tweet_text, :time_received => received_at} 
      #end
    end
  end
