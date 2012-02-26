require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'omniauth-facebook'
require 'tweetstream'
require 'fb_graph'
require 'tzinfo'
require 'nestful'
require 'json'
require 'net/http'
require 'uri'

require File.expand_path('../database', __FILE__)
require File.join(File.dirname(__FILE__), 'tweet_store')
#require File.join(File.dirname(__FILE__), 'tweet_filter')


SCOPE = 'email,offline_access,user_photos'
STORE = TweetStore.new

class App < Sinatra::Base

	configure do
  	set :public_folder, Proc.new { File.join(root, "static") }
  	enable :sessions
	end
  # server-side flow
  get '/' do
    # NOTE: you would just hit this endpoint directly from the browser
    #       in a real app. the redirect is just here to setup the root 
    #       path in this example sinatra app.
    #redirect '/auth/facebook'
    erb :index
    #erb "<a href='/auth/facebook'>Sign in with Facebook</a>"
  end

  get '/tweets' do
    #require 'ruby-debug/debugger'
    # @tweets = STORE.tweets
    # erb :tweets
    erb "Hello World"
  end
  
  get '/latest' do
    # We're using a Javascript variable to keep track of the time the latest
    # tweet was received, so we can request only newer tweets here. Might want
    # to consider using Last-Modified HTTP header as a slightly cleaner
    # solution (but requires more jQuery code).
    @tweets = STORE.tweets
    @tweet_class = 'latest'  # So we can hide and animate
    erb :latest#, :layout => false
  end

  # client-side flow
  get '/client-side' do

  	erb :clientside
    #content_type 'text/html'
    # NOTE: when you enable cookie below in the FB.init call
    #       the GET request in the FB.login callback will send
    #       a signed request in a cookie back the OmniAuth callback
    #       which will parse out the authorization code and obtain
    #       the access_token. This will be the exact same access_token
    #       returned to the client in response.authResponse.accessToken.

  end

  get '/auth/:provider/callback' do
  	omniauth = request.env['omniauth.auth']

    # create posterous page (only if one doesn't already exist)

    unless User.find_by_uid(omniauth[:uid])
      user = FbGraph::User.me(omniauth[:credentials][:token])
      user = user.fetch
      user_gender =  user.gender == "male" ? "he" : "she" if user.gender

      parametres = {
                      'site[hostname]' => "#{user.last_name}-twinderella",
                      'site[name]' => "#{user.first_name}'s' Twinderella",
                      'site[is_private]' => 0,
                      'site[is_group]' => 0,
                      'site[time_zone]' => ActiveSupport::TimeZone.new(user.timezone).name,
                      'site[subhead]' => "For when #{user_gender} is the Belle of the Ball",
                    }

      #create initial site
      #resp = Nestful.post "http://posterous.com/api/2/sites", {:format => :json, :params => parametres}

      uri = URI.parse("http://posterous.com/api/2/sites")

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Get.new(uri.request_uri)
      req.basic_auth("[api_key]", "artsicle")
      response = http.request(req)

      # Access the response body (JSON)
      site_id = JSON.parse(response.body)["id"] 

      #site_id = JSON.parse(resp)["id"]

      #style the site
      profile_pic = user.picture
      Nestful.put "http://posterous.com/api/2/sites/#{site_id}/profile/image", {:format => :json, :params => { "file" => profile_pic } } 

    end

  	User.create!(:uid => omniauth[:uid], :nickname => omniauth[:info][:nickname], :token => omniauth[:credentials][:token], :email => omniauth[:info][:email])

    api_key = "9c62b0d2526dee43a19e9a2e3c246dca"
    api_secret = "ac8af199056669266585dd34ee7680be"

    uids = "#{omniauth[:uid]}@facebook.com"
    namespace = "facebook.com"

    #callback = "AWS ip"

    # Face.com train call with user info
    Nestful.post "https://api.face.com/faces/train.json?api_key=#{api_key}&api_secret=#{api_secret}&uids=#{uids}&namespace=#{namespace}&user_auth=fb_user:#{omniauth[:uid]},fb_oauth_token:#{omniauth[:credentials][:token]}&", :format => :form


  	redirect '/success'
  end

  get '/success' do
  	#erb "success"
   erb :success
  end
  
  get '/auth/failure' do
    content_type 'application/json'
    MultiJson.encode(request.env)
  end

end



class User < ActiveRecord::Base
end








# configure do
#   set :public_folder, Proc.new { File.join(root, "static") }
#   enable :sessions
# end

# SCOPE = 'email,read_stream,offline_access,user_photos'

# TweetStream.configure do |config|
#   config.consumer_key = 'lDfxmkGkdIZrlMqxciCJ6A'
#   config.consumer_secret = 'u84I8ZGY9bjZl2GoG6BwLSV78oj7YtFLzr5ZMkgbfG8'
#   config.oauth_token = '90048571-JSrGz2lVHuKpqDLV6FFKI0dT51TNwsQfUs3nOtUGy'
#   config.oauth_token_secret = 'Kzp1P40Sa7X0aUADDKQThPUapghR2JfMb5iZc6j8qNY'
#   config.auth_method = :oauth
#   config.parser   = :yajl
# end

# use Rack::Session::Cookie
# use OmniAuth::Builder do
#   provider :facebook, '265707230172470', '7c3134b537fd40eb5ed5081df7dae700', :scope => SCOPE
#   #provider :twitter, 'consumerkey', 'consumersecret'
# end



# #class App < Sinatra::Base
# 	get '/' do
# 		#redirect '/auth/facebook'
# 	  erb "<a href='/auth/facebook'>Sign in with Facebook</a>"
	  
# 	end

# 	get '/clientside' do
# 		erb :clientside
# 	end

# 	get '/auth/:provider/callback' do
# 		  content_type 'application/json'
# 	    MultiJson.encode(request.env)
# 	  #auth = request.env['omniauth.auth']
# 	  # do whatever you want with the information!
# 	end

#   get '/auth/failure' do
#     content_type 'application/json'
#     MultiJson.encode(request.env)
#   end

# #end

# # get '/' do
# # 	"Hello World, it's #{Time.now} at the server!"
# # end


# #  media_url
# # tweet handle
# # location
# # time

# # @pic_urls = []
# # TweetStream::Client.new.track('photo') do |status, client|
# # 	if status.entities && status.entities.key?(:media) && status.entities.media.first["type"] == "photo"
# # 		@screen_name << status.user.screen_name
# #   	@pic_urls << status.entities.media.first['media_url']
# # 	end
# #   client.stop if @pic_urls.size >= 10
# # end
