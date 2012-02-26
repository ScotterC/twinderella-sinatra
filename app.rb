require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'omniauth-facebook'
require 'tweetstream'
require 'fb_graph'
require 'tzinfo'
require 'nestful'
require 'json'
require 'posterous'
require 'net/http'
require 'uri'
require 'open-uri'
require 'rest_client'

require 'ruby-debug' if ENV['RACK_ENV'] == 'development'

require File.expand_path('../database', __FILE__)
require File.join(File.dirname(__FILE__), 'tweet_store')
#require File.join(File.dirname(__FILE__), 'tweet_filter')


SCOPE = 'offline_access,user_photos'
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
     auth_params = {
      'username'  => ENV['POSTEROUS_EMAIL'],
      'password'  => ENV['POSTEROUS_PASSWORD'],
      'api_token' => ENV['POSTEROUS_API_TOKEN']
    }

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
                      'api_token' => auth_params['api_token']
                    }

      #create initial site
      #resp = Nestful.post "http://posterous.com/api/2/sites", {:format => :json, :params => parametres}

      uri = URI.parse("http://posterous.com/api/2/sites")

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(auth_params['username'], auth_params['password'])
      req.set_form_data(parametres)
      response = http.request(req)

      # Access the response body (JSON)
      site_id = JSON.parse(response.body)["id"] 

      # # create site profile

      uri = URI.parse("http://posterous.com/api/2/sites/#{site_id}/profile")

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(auth_params['username'], auth_params['password'])
      req.set_form_data({ "site_profile[body]" => "#{user.bio}\n#{user.about}", "site_profile[group_profile_name]" => "Magical Twinderella", 'api_token' => auth_params['api_token'] })
      response = http.request(req)


      # # get facebook profile picture
      # tempfile = Tempfile.new('profile.jpg')
      # http = Net::HTTP.new('www.facebook.com')
      # http.start() { |http|
      #   req = Net::HTTP::Get.new(user.picture)
      #   response = http.request(req)
        
      #   File.open(tempfile.path,'w') do |f|
      #     f.write response.body
      #   end
      # }

      #style the site
      #profile_pic = user.picture
      #Nestful.put "http://posterous.com/api/2/sites/#{site_id}/profile/image", {:format => :json, :params => { "file" => profile_pic } } 

      # update posterous theme
      uri = URI.parse("http://posterous.com/api/2/sites/#{site_id}/theme")

      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Post.new(uri.request_uri)
      req.basic_auth(auth_params['username'], auth_params['password'])
      req.set_form_data({ "theme[byline]" => "Media, Blog", 
                          "theme[friendly_name]" => "Starry-Eyed Surprise", 
                          "theme[raw_theme]" => "<!DOCTYPE html>\r\n<html lang=\"en\" xmlns:fb=\"http://www.facebook.com/2008/fbml\">\r\n<head>\r\n\t<meta charset=\"utf-8\">\r\n\t<link rel=\"icon\" href=\"/images/favicon.png\" type=\"image/x-png\">\r\n\t<title>{PageTitle}</title>\r\n      \r\n\t  \r\n<meta name=\"color:Headers\" content=\"#fff\"/>\r\n<meta name=\"color:Links\" content=\"#fff\"/>\r\n<meta name=\"color:PostInfo\" content=\"#ddd\"/>\r\n\r\n<style type=\"text/css\">\r\n\r\n\r\n* {padding:0;margin:0;}\r\nimg {border:0;}\r\n.clear {clear:both;font-size:5px;}\r\n.left {float:left;}\r\n.right {float:right;}\r\n.text-right {text-align:right;}\r\n.center {text-align:center;}\r\n.small {font-size:.857em !important;} /* 12px */\r\n.xsmall {font-size:.786em !important;} /* 11px */\r\n.xxsmall {font-size:9px;}\r\n.normal {font-size:12px !important;}\r\n.big {font-size:14px !important;}\r\n.bigger {font-size:16px !important;}\r\n.black {color:#000;}\r\n.green1,.green1:hover {color:#7ba709;}\r\n.green2,.green2:hover {color:#6f9904;}\r\n.darkgray {color:#333;}\r\n.strong {font-weight:bold;}\r\n.absolute-right {position:absolute;top:0;right:0;}\r\n.white {color:#fff;}\r\n.red {color:#f00;}\r\n\r\nheader,hgroup,footer,aside,nav,article,section {display:block;}\r\n\r\n/* Generated by Font Squirrel (http://www.fontsquirrel.com) on October 27, 2010 */\r\n\r\n@font-face {\r\n\tfont-family: 'ProximaNovaBold';\r\n\tsrc: url('/themes/starry_eyed_surprise/proxima_nova_bold-webfont.eot');\r\n\tsrc: local('0'), url('/themes/starry_eyed_surprise/proxima_nova_bold-webfont.ttf') format('truetype'), url('/themes/starry_eyed_surprise/proxima_nova_bold-webfont.svg#webfontzgJtBs53') format('svg');\r\n\tfont-weight: normal;\r\n\tfont-style: normal;\r\n}\r\n\r\n@font-face {\r\n\tfont-family: 'ProximaNovaRegular';\r\n\tsrc: url('/themes/starry_eyed_surprise/proxima_nova_reg-webfont.eot');\r\n\tsrc: local('0'), url('/themes/starry_eyed_surprise/proxima_nova_reg-webfont.ttf') format('truetype'), url('/themes/starry_eyed_surprise/proxima_nova_reg-webfont.svg#webfont5Tt5w4YL') format('svg');\r\n\tfont-weight: normal;\r\n\tfont-style: normal;\r\n}\r\n\r\nbody {\r\n\tbackground:url(/themes/starry_eyed_surprise/bg.jpg) no-repeat fixed center top #000;\r\n\tcolor:#fff;\r\n\tfont-family:\"Helvetica Neue\",Arial,Helvetica;\r\n\tfont-size:.875em; /* 14px */\r\n\t-webkit-font-smoothing:antialiased;\r\n}\r\n\r\na { color:#fff; text-decoration:underline; }\r\na:hover { color:#eee; }\r\n\r\n.container {\r\n\tmargin:0 auto;\r\n\tpadding:0 40px;\r\n\tposition:relative;\r\n\twidth:810px;\r\n}\r\n\r\n\t.cw {\r\n\t\tbottom:-70px;\r\n\t\tcolor:#92ABBD;\r\n\t\tfont-family:ProximaNovaBold;\r\n\t\tfont-size:1.6em;\r\n\t\tline-height:1em;\r\n\t\ttext-shadow:-1px -1px 0 rgba(0,0,0,.5);\r\n\t\tpadding-bottom:20px;\r\n\t\tposition:absolute;\r\n\t\ttext-align:center;\r\n\t\twidth:810px;\r\n\t}\r\n\t\r\n\t\t.cw a {\r\n\t\t\tcolor:#92ABBD;\r\n\t\t\ttext-decoration:none;\r\n\t\t}\r\n\t\t\r\n\t\t\t.cw a:hover {\r\n\t\t\t\tcolor:#fff;\r\n\t\t\t}\r\n\r\n\tarticle header h1 {\r\n\t\tfont-family:ProximaNovaBold;\r\n\t\tfont-size:1.6em;\r\n\t\tfont-weight:normal;\r\n\t\tline-height:1em;\r\n\t\tpadding-bottom:15px;\r\n\t\ttext-shadow:-1px -1px 0 rgba(0,0,0,.5);\r\n\t}\r\n\r\n\t\tarticle header h1 a {\r\n\t\t\tcolor:{color:Headers};\r\n\t\t\ttext-decoration:none;\r\n\t\t}\r\n\t\t\r\n\t\tarticle header h1 a:hover {\r\n\t\t}\r\n\r\nheader#page_header {\r\n\tpadding-bottom:10px;\r\n}\r\n\r\n.header_image {\r\n\tpadding-bottom:10px;\r\n}\r\n\r\n\t.header_image img {\r\n\t\tmax-width:810px;\r\n\t}\r\n\r\nheader#page_header hgroup {\r\n\tpadding:20px 0 10px;\r\n}\r\n\r\n\theader#page_header hgroup h1 {\r\n\t\tdisplay:inline-block;\r\n\t\tfont-family:ProximaNovaBold;\r\n\t\tfont-size:2em;\r\n\t\tfont-weight:normal;\r\n\t\tline-height:1em;\r\n\t\tmargin-right:10px;\r\n\t\ttext-transform:uppercase;\r\n\t\ttext-shadow:-1px -1px 0 rgba(0,0,0,.5);\r\n\t}\r\n\r\n\t\theader#page_header hgroup h1 a {\r\n\t\t\tcolor:{color:Headers};\r\n\t\t\ttext-decoration:none;\r\n\t\t}\r\n\r\n\theader#page_header hgroup h2 {\r\n\t\tdisplay:inline-block;\r\n\t\tfont-family:ProximaNovaRegular;\r\n\t\tfont-size:1.143em;\r\n\t\tfont-weight:normal;\r\n\t}\r\n\r\n\r\nnav {\r\n\t/* margin:4px 0 0 25px; */\r\n}\r\n\r\n\tnav li {\r\n\t\tdisplay:block;\r\n\t\tfloat:left;\r\n\t\tfont-family:ProximaNovaBold;\r\n\t\tfont-size:14px;\r\n\t\tlist-style:none;\r\n\t\tmargin-top:0; /* override default */\r\n\t\tmargin-right:10px;\r\n\t\tmargin-bottom:10px;\r\n\t\ttext-shadow:-1px -1px 0 rgba(0,0,0,.5);\r\n\t\ttext-transform:uppercase;\r\n\t}\r\n\t\r\n\t\tnav li a {\r\n\t\t\tdisplay:block;\r\n\t\t\tpadding:4px 6px;\r\n\t\t\ttext-decoration:none;\r\n\t\t}\r\n\t\r\n\t\tnav li a:hover,nav li a:active,nav li a.current {\r\n\t\t\t-webkit-border-radius:4px;\r\n\t\t\t-moz-border-radius:4px;\r\n\t\t\tborder-radius:4px;\r\n\t\t}\r\n\t\t\r\n\t\tnav li a:hover {\r\n\t\t\tbackground:rgba(0,0,0,.2);\r\n\t\t}\r\n\t\t\r\n\t\tnav li a:active {\r\n\t\t\tbackground:rgba(0,0,0,.4);\r\n\t\t}\r\n\t\t\r\n\t\tnav li a.current {\r\n\t\t\tbackground:rgba(0,0,0,.3);\r\n\t\t}\r\n\r\nform.search input.text {\r\n\tfont-size: 12px;\r\n\tpadding: 2px 2px 2px 20px;\r\n\tborder: 1px solid #ccc;\r\n\tbackground:#fff url('/images/icons/search16.png') no-repeat 3px 3px;\r\n\t-moz-border-radius: 3px;\r\n\t-webkit-border-radius: 3px;\r\n\tborder-radius: 3px;\r\n}\r\n\r\naside#sidebar {\r\n\tfloat:right;\r\n\twidth:225px;\r\n}\r\n\r\n\taside#sidebar a {\r\n\t\tcolor:{color:Links};\r\n\t\ttext-decoration:none;\r\n\t}\r\n\t\r\n\taside#sidebar a:hover {\r\n\t\ttext-decoration:underline;\r\n\t}\r\n\r\naside#sidebar section {\r\n\tdisplay:block;\r\n\tfont-family:ProximaNovaRegular;\r\n\tpadding:0 0 30px;\r\n}\r\n\r\n\taside section#profile {\r\n\t}\r\n\r\n\taside#sidebar section h1 {\r\n\t\tcolor:#92abbd;\r\n\t\tfont-family:ProximaNovaBold;\r\n\t\tfont-size:1.143em;\r\n\t\tfont-weight:normal;\r\n\t\ttext-transform:uppercase;\r\n\t}\r\n\t\r\n\taside#sidebar section ul li {\r\n\t\tfont-size:.857em;\r\n\t\tlist-style: none;\r\n\t\tline-height:1.4em;\r\n\t}\r\n\t\r\n\taside#sidebar section div.archive_list {\r\n\t\tfont-size:.857em;\t  \r\n    line-height:1.4em;\r\n    margin-top:5px;        \r\n  }\r\n  \r\n  aside#sidebar section div.archive_list div.archive {\r\n      margin-bottom:5px;        \r\n  }\r\n  \r\n  aside#sidebar section div.archive_list div.inner {\r\n    margin-left:10px;\r\n    margin-bottom:7px;\r\n  }\r\n\t\r\n\t.profile_image {\r\n\t\tbackground:rgba(0,0,0,.25);\r\n\t\tborder:solid 1px #222;\r\n\t\t-moz-border-radius:4px;\r\n\t\t-webkit-border-radius:4px;\r\n\t\tborder-radius:4px;\r\n\t\tmargin-bottom:10px;\r\n\t\tpadding:5px;\r\n\t}\r\n\t\r\n\t.profile p {\r\n\t\tline-height:1.5em;\r\n\t\tpadding-top:5px;\r\n\t}\r\n\t\r\n\t.external {\r\n\t\tpadding-top:5px;\r\n\t}\r\n\r\n#search {\r\n\tpadding:15px 0;\r\n}\r\n\r\n\t#searchbox {\t\t\r\n\t\tbackground:url(/themes/starry_eyed_surprise/search-white-50.png) no-repeat 8px 9px rgba(10,10,10,.3);\r\n\t\tborder:solid 1px #202020;\r\n\t\t-webkit-border-radius:4px;\r\n\t\t-moz-border-radius:4px;\r\n\t\tborder-radius:4px;\r\n\t\tcolor:#ccc;\r\n\t\tfont-size:16px;\r\n\t\tmargin:10px 0;\r\n\t\tpadding:5px 10px 5px 25px;\r\n\t\twidth:185px;\r\n\t}\r\n\t\t\t\t\r\n\t\t#searchbox:focus {\r\n\t\t\tcolor:#eee;\r\n\t\t}\r\n\t\r\n\t#searchbox_button {\r\n\t\tfont-size:.875em;\r\n\t\tfont-weight:bold;\r\n\t\theight:auto;\r\n\t\tmargin-top:5px;\r\n\t\tpadding:3px 10px;\r\n\t}\r\n\r\nsection#search_results {\r\n\tbackground:rgba(0,0,0,.25);\r\n\t-moz-border-radius:5px;\r\n\t-webkit-border-radius:5px;\r\n\tborder-radius:5px;\r\n\tborder:solid 1px rgba(0,0,0,.35);\r\n\tpadding:10px;\r\n\tmargin-bottom:35px;\r\n}\r\n\r\n\tsection#search_results a {\r\n\t\ttext-decoration:none;\r\n\t}\r\n\r\n\tsection#search_results .submit {\r\n\t\tfont-size:.875em;\r\n\t\tfont-weight:bold;\r\n\t\theight:auto;\r\n\t\tmargin-top:5px;\r\n\t\tpadding:3px 10px;\r\n\t}\r\n\r\n\tsection#search_results h1,section#filed_under h1 {\r\n\t\tcolor:{color:Headers};\r\n\t\tfont-size:1.429em;\r\n\t\tline-height:1em;\r\n\t}\r\n\t\r\n\tsection#filed_under h1 {\r\n\t\tfont-size:1em;\r\n\t\tmargin-bottom:25px;\r\n\t}\r\n\t\r\n\tsection#search_results ul {}\r\n\t\t\r\n\t\tsection#search_results li {\r\n\t\t\tdisplay:inline-block;\r\n\t\t\tfont-size:.786em;\r\n\t\t\tlist-style:none;\r\n\t\t\tmargin-right:5px;\r\n\t\t}\r\n\t\t\r\n\t.back_to_blog {\r\n\t\tdisplay:block;\r\n\t\tfont-weight:bold;\r\n\t\tmargin-bottom:15px;\r\n\t}\r\n\t\t\r\n\t\t.back_to_blog a {\r\n\t\t\ttext-decoration:none;\r\n\t\t}\r\n\r\n.profile-link {\r\n\tcolor:#92abbd !important;\r\n\tfont-family:ProximaNovaBold;\r\n\tfont-size:1.143em;\r\n\ttext-transform:uppercase;\r\n}\r\n\r\nsection#contributors li a:first-child {\r\npadding-right:3px;\r\ntext-decoration:none;\r\n}\r\n\r\n\tsection#contributors li a img {\r\n\t\tbackground:rgba(0,0,0,.25);\r\n\t\tborder:solid 1px #222;\r\n\t\t-moz-border-radius:2px;\r\n\t\t-webkit-border-radius:2px;\r\n\t\tborder-radius:2px;\r\n\t\theight:20px;\r\n\t\tpadding:3px;\r\n\t\tvertical-align:middle;\r\n\t\twidth:20px;\r\n\t}\r\n\t\r\n\tsection#contributors li a {\r\n\t\tvertical-align:middle;\r\n\t}\r\n\r\n  section#subscriptions {\r\n      padding-bottom:3px !important;\r\n      font-size:.857em;    \r\n  }\r\n\r\n      section#subscriptions h1 {\r\n          padding-bottom:5px;\r\n      }\r\n\r\n  section#rss {\r\n      padding-top:3px !important;\r\n  }\r\n\r\n  section#subscriptions a {\r\n      font-size:1em;\r\n      height:14px;\r\n  }\r\n\r\n  section#rss a {\r\n      display:block;\r\n      font-size:.857em;\r\n      height:14px;\r\n      padding-left:18px;\r\n  }\r\n\r\n  section#subscriptions .subscribe-site {\r\n      background:url(/images/favicon.png) no-repeat -1px -1px;\r\n  }\r\n\r\n  section#subscriptions .subscribe-site div {\r\n      padding-left:18px;\r\n  }\r\n\r\n  section#rss a {\r\n      background:url(/images/feed-icon-14x14.png) no-repeat -1px -1px;\r\n  }\r\n\r\nsection#statistics {\r\n\tfont-size: 10px;\r\n}\r\n\r\nsection#statistics strong {\r\n}\r\n\r\nsection#tags li.selected a {\r\n\tfont-weight:bold;\r\n}\r\n\r\n\tsection#tags li.selected a:hover {\r\n\t\tcursor:pointer;\r\n\t}\r\n\t\r\nsection#fans {\r\n}\r\n\r\n\tsection#fans h1 {\r\n\t\tfont-size:.786em;\r\n\t}\r\n\r\n\tsection#fans li {\r\n\t\tlist-style:none;\r\n\t}\r\n\r\n\t\tsection#fans li a img {\r\n\t\t\tbackground:rgba(0,0,0,.25);\r\n\t\t\tborder:solid 1px #222;\r\n\t\t\t-moz-border-radius:2px;\r\n\t\t\t-webkit-border-radius:2px;\r\n\t\t\tborder-radius:2px;\r\n\t\t\theight:20px;\r\n\t\t\tpadding:3px;\r\n\t\t\tvertical-align:middle;\r\n\t\t\twidth:20px;\r\n\t\t}\r\n\t\t\r\n\t\tsection#fans li a {\r\n\t\t\tcolor:{color:PostInfo};\r\n\t\t\tfont-size:.786em;\r\n\t\t\ttext-decoration:none;\r\n\t\t\tvertical-align:middle;\r\n\t\t}\r\n\r\n\r\narticle header aside.sms {\r\n\tfont-size: 11px;\r\n}\r\n\r\nfooter section.locations h1 {\r\n\tfont-weight: normal;\r\n\tline-height: 21px;\r\n\tmargin-top: 0px;\r\n}\r\n\r\ninput, select, textarea {\r\n\tfont-size: 1.6em;\r\n\tline-height:1.3em !important;\r\n\tpadding: 5px;\r\n}\r\n\r\ninput[type='text'], input[type='password'], select, textarea {\r\n\tbackground-color: #fff;\r\n\tborder: 1px solid #ccc;\r\n}\r\n\r\ninput[type='button'], input[type='submit'] {\r\n\theight: 2em;\r\n\tfont-size: 1.4em;\r\n\tcolor: #000;\r\n\tmargin-top: 10px;\r\n}\r\n\r\nsection.share {\r\n\tmargin-bottom: 18px;\r\n}\r\n\r\n#post_column {\r\n\tfloat:left;\r\n\twidth:552px;\r\n}\r\n\t\t\r\n\t\t#post_column .body a {\r\n\t\t\tcolor:{color:Links};\r\n\t\t}\r\n\t\t\r\n\t\t#post_column a:hover {\r\n\t\t}\r\n\r\n\tdiv#articles {\r\n\t}\r\n\t\r\n\t\tarticle {\r\n\t\t\tmargin-bottom:50px;\r\n\t\t\tposition:relative;\r\n\t\t}\r\n\t\t\r\n\t\t.postblock {\r\n\t\t\tbackground:rgba(255,255,255,.25);\r\n\t\t\t-webkit-box-shadow:2px 2px 5px #000;\r\n\t\t\t-moz-box-shadow:2px 2px 5px #000;\r\n\t\t\tbox-shadow:2px 2px 5px #000;\r\n\t\t\tborder:solid 1px rgba(255,255,255,.15);\r\n\t\t\t-webkit-border-radius:8px;\r\n\t\t\t-moz-border-radius:8px;\r\n\t\t\tborder-radius:8px;\r\n\t\t\tpadding:25px;\r\n\t\t\twidth:500px;\r\n\t\t}\r\n\t\r\n\t\t\t.postunit .edit-post {\r\n\t\t\t\tdisplay:none;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t.postunit:hover .edit-post {\r\n\t\t\t\tdisplay:block;\r\n\t\t\t\tleft:0;\r\n\t\t\t\tposition:absolute;\r\n\t\t\t\ttop:-25px;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t.fav_star {\r\n\t\t\t\tfont-size:9px !important;\r\n\t\t\t\tmargin-top:9px !important;\r\n\t\t\t\tmargin-right:9px !important;\r\n\t\t\t\ttext-align:right;\r\n\t\t\t\twidth:80px;\r\n\t\t\t\tz-index:11;\r\n\t\t\t}\r\n\t\t\r\n\t\t\tarticle header {\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tarticle header section {\r\n\t\t\t\tmin-height:40px;\r\n\t\t\t\tpadding-top:17px;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tarticle header aside.sms {\r\n\t\t\t\tfloat:left;\r\n\t\t\t\tpadding-top:10px;\r\n\t\t\t}\r\n\t\t\r\n\t\tdiv.editbox {\r\n\t\t\theight:16px;\r\n\t\t\tposition:absolute;\r\n\t\t\ttop:0px;\r\n\t\t\tvisibility:hidden;\r\n\t\t}\r\n\t\t\r\n\t\t\tdiv.editbox ul.mini_commands {\r\n\t\t\t\tmargin-top:0;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\tul.mini_commands li a {\r\n\t\t\t\t\tcolor:{color:Links};\r\n\t\t\t\t}\r\n\t\t\t\r\n\t\t\tarticle:hover div.editbox {\r\n\t\t\t\tvisibility:visible;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t.hr {\r\n\t\t\tbackground:rgba(0,0,0,.2);\r\n\t\t\t-webkit-border-radius:3px;\r\n\t\t\t-moz-border-radius:3px;\r\n\t\t\tborder-radius:3px;\r\n\t\t\t-webkit-box-shadow:1px 1px 1px rgba(255,255,255,.3);\r\n\t\t\t-moz-box-shadow:1px 1px 1px rgba(255,255,255,.3);\r\n\t\t\tbox-shadow:1px 1px 1px rgba(255,255,255,.3);\r\n\t\t\theight:3px;\r\n\t\t\twidth:100%;\r\n\t\t}\r\n\t\t\t\r\n\t\tarticle div.body {\r\n\t\t\tfont-family:\"Helvetica Neue\",Helvetica,Arial,Sans-Serif;\r\n\t\t\tpadding-top:10px;\r\n\t\t\ttext-shadow:1px 1px 1px #363636;\r\n\t\t\tfilter:dropshadow(color=#363636, offx=1, offy=1);\r\n\t\t}\r\n\t\t\r\n\t\t\tarticle div.body div.inner {\r\n\t\t\t\tline-height:1.5em;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\tarticle div.body div.inner > :first-child {\r\n\t\t\t\t\tmargin-bottom:0;\r\n\t\t\t\t\tmargin-top:0;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tarticle div.body div.inner > p:first-child {\r\n\t\t\t\t\t/* margin-top:15px; */\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tarticle div.body p, article div.body blockquote {\r\n\t\t\t\t\tmargin:15px 0 18px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tarticle div.body div.posterousGalleryMainDiv {\r\n\t\t\t\t\tmargin:0 0 15px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tdiv.posterousVideoMainDiv {\r\n\t\t\t\t\tmargin:0;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t.posterousGalleryMainDiv a.posterousGalleryMainlink {\r\n\t\t\t\t\ttext-decoration:none !important;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tarticle div.body div.inner a {\r\n\t\t\t\t\ttext-decoration:underline;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t\tarticle div.body div.inner a:hover {\r\n\t\t\t\t\t}\r\n\t\t\t\t\t\r\n\t\t\t\t\tarticle div.body div.inner ul,article div.body div.inner ol {\r\n\t\t\t\t\t\tpadding-bottom:5px;\r\n\t\t\t\t\t\tpadding-left:30px;\r\n\t\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t.galleryLabel {\r\n\t\t\t\t\tcolor:#fff;\r\n\t\t\t\t}\r\n\t\t\t\t\t\r\n\t\t\t\t.inner blockquote {\r\n\t\t\t\t\tborder-left:solid 4px #000 !important;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\tarticle footer {\r\n\t\t\tmargin-top:10px;\r\n\t\t\tposition:relative;\r\n\t\t}\r\n\r\n\t\t\tfooter section {\r\n\t\t\t\tmargin-bottom:10px;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\tfooter section.author {\r\n\t\t\t\t\tcolor:{color:PostInfo};\r\n\t\t\t\t\tfont-size:.857em !important;\r\n\t\t\t\t\tpadding-bottom:10px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t\tfooter section.author a {\r\n\t\t\t\t\t\tcolor:{color:Links} !important;\r\n\t\t\t\t\t\ttext-decoration:none;\r\n\t\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t\tfooter section.author h1 {\r\n\t\t\t\t\t\tdisplay:inline;\r\n\t\t\t\t\t\tfont-size:1em;\r\n\t\t\t\t\t\tfont-weight:normal;\r\n\t\t\t\t\t}\r\n\t\t\t\t\t\r\n\t\tfooter section.comments_box {\r\n\t\t\tmargin-top:15px;\r\n\t\t\tpadding:10px 0;\r\n\t\t}\r\n\r\n\t\t\tfooter section.comments h1 {\r\n\t\t\t\tfont-size:.857em;\r\n\t\t\t\tfont-weight:normal;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\tfooter section.comments h1 a {\r\n\t\t\t\t\ttext-decoration:none;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t.comment-link {\r\n\t\t\t\t\tfont-size:.857em;\r\n\t\t\t\t\tfont-weight:normal;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t\t.comment-link a {\r\n\t\t\t\t\t\ttext-decoration:none;\r\n\t\t\t\t\t}\r\n\t\t\t\r\n\t\t\tdiv.comment_none_yet_msg {\r\n\t\t\t\tfont-style:italic;\r\n\t\t\t\tfont-weight:normal;\r\n\t\t\t\tmargin-top:5px;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\tdiv.comment_none_yet_msg,div.commentunit {\r\n\t\t\t\t\tcolor:#fff;\r\n\t\t\t\t}\r\n\t\t\t\r\n\t\t\t.commentunit .comment_value label {\r\n\t\t\t\tcolor:#fff !important;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tfooter section.comments section h1 {\r\n\t\t\t\tfont-size:1em;\r\n\t\t\t\tfont-weight:bold;\r\n\t\t\t}\r\n\t\t\tdiv.comment {\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tdiv.comment b {\r\n\t\t\t\tfont-weight:normal;\r\n\t\t\t}\r\n\r\n\r\n\t\t\tdiv.comment_label {\r\n\t\t\t\tpadding-top: 2px;\r\n\t\t\t\tmargin-top: 0px;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\r\n\t\t\tdiv.comment_date {\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tdiv.commentunit {\r\n\t\t\t\t/* margin: 10px 0px; */\r\n\t\t\t\tpadding:5px 0;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t.comment_profile_description {\r\n\t\t\t\tfont-weight:bold;\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\t\t.comment_profile_description div {\r\n\t\t\t\t\tfont-weight:normal;\r\n\t\t\t\t}\r\n\t\t\t\r\n\t\t\tdiv.comment_value {\r\n\t\t\t}\r\n\r\n\t\t\tdiv.comment_avatar {\r\n\t\t\t\tmargin-top:10px;\r\n\t\t\t}\r\n\r\n\t\t\tdiv.commentunit div.profile_icon {\r\n\t\t\t\tmargin-top:5px;\r\n\t\t\t}\r\n\r\n\t\t\tdiv.commentname {\r\n\t\t\t\tmargin-bottom:5px;\r\n\t\t\t}\r\n\r\n\t\t\tdiv.comment_loading_div {\r\n\t\t\t/* margin-left:155px; */\r\n\t\t\t}\r\n\t\t\t\r\n\t\t\tdiv.comment_area {\r\n\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tfooter section.comments h4 {\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t.comment_value input[type=\"submit\"] {\r\n\t\t\t\t\tfont-size:.875em;\r\n\t\t\t\t\tfont-weight:bold;\r\n\t\t\t\t\theight:auto;\r\n\t\t\t\t\tmargin-top:5px;\r\n\t\t\t\t\tpadding:3px 10px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tfooter section .comment_loading_div {\r\n\t\t\t\t\tbackground:url(/themes/starry_eyed_surprise/loading1-white.gif) no-repeat;\r\n\t\t\t\t\tdisplay:inline-block;\r\n\t\t\t\t\theight:11px;\r\n\t\t\t\t\twidth:16px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\tfooter section .comment_loading_div {\r\n\t\t\t\t\tmargin-top:5px;\r\n\t\t\t\t}\r\n\t\t\t\t\r\n\t\t\t\t\tfooter section .comment_loading_div img {\r\n\t\t\t\t\t\tdisplay:none;\r\n\t\t\t\t\t}\r\n\r\ndiv.posterous_comments h4, div.spanningheader h4 {\r\n\tmargin:0;\r\n}\r\n\r\n.dark .p_responses_list .p_info, .dark .p_responses_list .p_info time {color:#fff;}\r\n.dark div.p_response_container header h1 {\r\n  width:200px;\r\n  font-family: \"Helvetica Neue\",Arial,Helvetica;\r\n  text-shadow: none;\r\n  font-size: 12px;\r\n}\r\n.dark .p_response_widget ul li, .dark .p_response_widget ul li a {background:rgba(255,255,255,.25);}\r\n.dark .p_response_widget ul li a, .dark .p_response_widget ul li {color:#fff !important;}\r\n\r\n\r\narticle footer time div {display:inline;}\r\n\r\nfooter section.tags {\r\n\tcolor:{color:PostInfo};\r\n\tfont-size:.857em !important;\r\n\tpadding-bottom:10px;\r\n}\r\n\t\r\n\tfooter section.tags a {\r\n\t\tcolor:{color:Links} !important;\r\n\t\ttext-decoration:none;\r\n\t}\r\n\r\n\tfooter section.tags h1 {\r\n\t\tdisplay:inline;\r\n\t\tfont-size:11px;\r\n\t\tmargin:0;\r\n\t\tpadding-right:5px;\r\n\t}\r\n\t\r\n\tfooter section.tags h1 span {\r\n\t\tfont-weight:normal;\r\n\t}\r\n\t\r\n\tfooter section.tags ul {\r\n\t\tdisplay:inline;\r\n\t\tmargin:0;\r\n\t}\r\n\t\r\n\tfooter section.tags ul li {\r\n\t\tdisplay:inline;\r\n\t\tlist-style:none outside none;\r\n\t\tpadding-right:10px;\r\n\t}\r\n\t\r\n\tfooter section.tags ul li a {\r\n\t\tcolor:{color:Links};\r\n\t}\r\n\t\r\n\tfooter section.locations {\r\n\t\tmargin-top:10px;\r\n\t\tmargin-bottom:0;\r\n\t}\r\n\t\r\n\tfooter section.locations h2 {\r\n\t\tfont-size:11px;\r\n\t\tmargin-top:0;\r\n\t}\r\n\t\r\n\tfooter section.locations ul {\r\n\t\tdisplay:block;\r\n\t\tmargin:0;\r\n\t}\r\n\t\r\n\tfooter section.locations ul li {\r\n\t\tdisplay:block;\r\n\t\tlist-style:none outside none;\r\n\t}\r\n\t\r\n\tfooter section.locations div.location_detail {\r\n\t\tbackground:rgba(0,0,0,.25);\r\n\t\t-moz-border-radius:5px;\r\n\t\t-webkit-border-radius:5px;\r\n\t\tborder-radius:5px;\r\n\t\tborder:solid 1px rgba(0,0,0,.35);\r\n\t\tmargin:10px 0;\r\n\t\toverflow:auto;\r\n\t\tpadding:8px;\r\n\t}\r\n\t\r\n\tfooter section.locations div.location_detail div.map {\r\n\t\tfloat:left;\r\n\t\theight:150px;\r\n\t\twidth:300px;\r\n\t}\r\n\t\r\n\tfooter section.locations div.location_detail div.summary {\r\n\t\tfloat:right;\r\n\t\twidth:172px;\r\n\t}\r\n\t\r\n\tfooter section.share, footer section.tags, footer section.locations {\r\n\t\tdisplay:block;\r\n\t\t/* margin-left:155px; */\r\n\t}\r\n\r\nfooter#pagination {\r\n\t/* margin-left:155px; */\r\n\toverflow:hidden;\r\n\tpadding-bottom:50px;\r\n}\r\n\r\n\t.pagination {\r\n\t\tmargin:3px;\r\n\t\tpadding:3px;\r\n\t\ttext-align:center;\r\n\t}\r\n\r\n\t.pagination a {\r\n\t\tbackground:rgba(255,255,255,.1);\r\n\t\tborder:solid 1px {color:Links};\r\n\t\tcolor:{color:Links};\r\n\t\tmargin:2px;\r\n\t\tpadding:0 5px;\r\n\t\ttext-decoration:none;\r\n\t}\r\n\t\r\n\t.pagination span.disabled {\r\n\t\tborder:solid 1px rgba(255,255,255,.1);\r\n\t\tcolor:rgba(255,255,255,.25);\r\n\t\tmargin:2px;\r\n\t\tpadding:2px 5px;\r\n\t}\r\n\t\r\n\t.pagination a:hover, .pagination a:active {\r\n\t\tborder:solid 1px rgba(255,255,255,.3);\r\n\t\tcolor:#fff;\r\n\t}\r\n\t\r\n\t.pagination span.current {\r\n\t\tcolor:#fff;\r\n\t\tfont-weight:bold;\r\n\t\tpadding:2px 5px;\r\n\t\tmargin:2px;\r\n\t}\r\n\r\nfooter section.share {\r\nheight:25px;\r\n}\r\n\r\n/* misc */\r\n\r\ndiv.ajaxResult {\r\ncolor:#009900;\r\nfont-size:10px;\r\nmargin-bottom:10px;\r\n}\r\n\r\n\tdiv.retweet {\r\n\tbackground:url(\"/images/icons/services/twitter11.png\") no-repeat scroll left center transparent;\r\n\tdisplay:inline-block;\r\n\tmin-height:11px;\r\n\tmin-width:1px;\r\n\tpadding-left:15px;\r\n\tvertical-align:middle;\r\n\t}\r\n\t\r\n\t.twitter-share-button {\r\n\tfloat:left;\r\n\t}\r\n\t\r\n\tdiv.facebook_like {\r\n\tdisplay:inline;\r\n\tfloat:left;\r\n\tmargin-left:5px;\r\n\tposition:relative;\r\n\t}\r\n\r\ntable {\r\nborder:medium none;\r\nborder-spacing:0;\r\nfont-size:11px;\r\nline-height:16px;\r\nmargin:10px 0 0;\r\ntext-align:left;\r\n}\r\n\r\n\ttd {\r\n\tborder-color:-moz-use-text-color -moz-use-text-color #EEEEEE;\r\n\tborder-style:none none solid;\r\n\tborder-width:medium medium 1px;\r\n\tmargin:0;\r\n\tpadding:4px;\r\n\tvertical-align:top;\r\n\t}\r\n\t\r\n\tth {\r\n\tborder-color:-moz-use-text-color -moz-use-text-color #CCCCCC;\r\n\tborder-style:none none solid;\r\n\tborder-width:medium medium 1px;\r\n\tfont-weight:bold;\r\n\tpadding:4px;\r\n\ttext-align:left;\r\n\tvertical-align:bottom;\r\n\t}\r\n\r\nhr {\r\nborder:1px solid #DDDDDD;\r\nmargin-bottom:10px;\r\nmargin-top:10px;\r\n}\r\n\r\ndiv.posterousListComments div.comment, div.posterousAddNewComment div.comment, div.posterousAddNewComment div.comment_value {\r\n/* margin-left:25px; */\r\n}\r\n\r\nsection.private {\r\n\tleft:-25px;\r\n\tposition:absolute;\r\n\ttop:2px;\r\n}\r\n\r\n\tarticle header section.private {\r\n\t\tmin-height:0; /* overwrite default */\r\n\t\tpadding-top:0; /* overwrite default */\r\n\t}\r\n\t\r\n\tsection.private:hover div.private_post_message {\r\n\tdisplay:block;\r\n\t}\r\n\tdiv.private_post_message {\r\n\t-moz-border-radius:5px;\r\n\t-webkit-border-radius:5px;\r\n\tborder-radius:5px;\r\n\tborder: solid 1px rgba(0,0,0,.75);\r\n\tbackground:rgba(0,0,0,.25);\r\n\tcolor:#fff;\r\n\tdisplay:none;\r\n\tpadding:10px;\r\n\tposition:absolute;\r\n\tright:-5px;\r\n\ttext-align:left;\r\n\ttop:-5px;\r\n\twidth:100px;\r\n\t}\r\n\tdiv.private_post_message h1 {\r\n\tfloat:none;\r\n\tfont-size:11px;\r\n\tmargin:0 0 5px;\r\n\tpadding:0;\r\n\twidth:auto;\r\n\t}\r\n\tdiv.private_post_message p {\r\n\tfont-size:10px;\r\n\tmargin:0;\r\n\t}\r\n\t\r\n\tdiv.posterous_retweet_widget {\r\n\tmargin:0 0 10px;\r\n\t}\r\n\r\n</style>\r\n\r\n\r\n<!--[if lt IE 9]>\r\n<style type=\"text/css\">\r\n    nav li a.current {\r\n        background:url(/themes/starry_eyed_surprise/post-bg.png) repeat;\r\n    }\r\n    #searchbox {\r\n\t\tbackground:url(/themes/starry_eyed_surprise/search-white-50.png) no-repeat 8px 9px #0a0a0a;\r\n\t}\r\n    .postblock {\r\n        background:url(/themes/starry_eyed_surprise/post-bg.png) repeat;\r\n        border:solid 1px #777;\r\n        padding:25px;\r\n    }\r\n    div.body,.taglist li {\r\n        filter:DropShadow(Color=#363636, OffX=1, OffY=1, Positive=1);\r\n    }\r\n\t\t\t\r\n    .hr {\r\n\t    display:none;\r\n    }\r\n</style>\r\n<![endif]-->\r\n</head>\r\n\r\n<body>\r\n{block:PosterousHeader /}\r\n<div class=\"container\">\r\n\t<div class=\"cw\"><a href=\"http://themes.corywatilo.com\" target=\"_blank\">Posterous theme</a> by <a href=\"http://corywatilo.com\" target=\"_blank\">Cory Watilo</a><img src=\"http://c.statcounter.com/6339963/0/500071fc/1/\"></div>\r\n\t<header id=\"page_header\">\r\n        {block:HeaderImage}\r\n          <h1 class=\"header_image\"><a href=\"{SiteURL}\" title=\"{Title}\" rel=\"index\"><img src=\"{HeaderImageURL}\" alt=\"{Title} - {Description}\"></a></h1>\r\n        {Else}\r\n\t\t\t<hgroup>\r\n\t\t\t\t<h1><a href=\"{SiteURL}\" title=\"{Title}\" rel=\"index\">{Title}</a></h1>\r\n\t\t\t\t{block:Description}\r\n\t\t\t\t\t<h2>{Description}</h2>\r\n\t\t\t\t{/block:Description}\r\n\t\t\t</hgroup>\r\n        {/block:HeaderImage}\r\n        {block:HasPages}\r\n          <nav id=\"navigation\">\r\n\t\t\t<ul>\r\n\t\t\t  {block:Pages}\r\n\t\t\t\t<li><a href=\"{URL}\" class=\"{Current}\" rel=\"{External}\">{Label}</a></li>\r\n\t\t\t  {/block:Pages}\r\n\t\t\t</ul>\r\n           </nav>\r\n           <div class=\"clear\"></div>\r\n         {/block:HasPages}\r\n    </header>\r\n\r\n                <aside id=\"sidebar\">\r\n                        <section id=\"profile\">\r\n                          <h1>\r\n                            <a href=\"{ProfileLink}\" title=\"{OwnerName}'s profile\">\r\n                              <img src=\"#{user.picture}\" alt=\"{OwnerName}\" class=\"profile_image\">\r\n                            </a>\r\n                          </h1>\r\n                          <a href=\"{ProfileLink}\" class=\"profile-link\">{OwnerName}</a>\r\n                          <div class=\"profile\">\r\n\t                          <p>{Profile}</p>\r\n                          </div>\r\n                          <div class=\"external\">{ProfileExternalLinks}</div>\r\n                        </section>\r\n                        \r\n                        {block:HasLinks}\r\n                          {block:LinkCategories}\r\n                            <section class=\"links\">\r\n                              <h1>{Label}</h1>\r\n                              <ul>\r\n                                {block:Links}\r\n                                  <li><a href=\"{URL}\" rel=\"external\">{Label}</a></li>\r\n                                {/block:Links}\r\n                              </ul>\r\n                            </section>\r\n                          {/block:LinkCategories}\r\n                        {/block:HasLinks}\r\n\r\n                        \r\n                          <section id=\"rss\">\r\n                            <a href=\"{RSS}\" rel=\"alternate\" type=\"application/rss+xml\">Subscribe via RSS</a>\r\n                          </section>\r\n        \r\n                        {block:NotSearchOrTag}\r\n                          <section id=\"search\">\r\n                            <form class=\"search\">\r\n                              <input type=\"hidden\" name=\"sort\" value=\"{SearchSort}\">\r\n                              <input type=\"text\" name=\"search\" class=\"text\" value=\"{SearchQuery}\" id=\"searchbox\">\r\n                              <input type=\"submit\" value=\"Search\" class=\"submit\" id=\" \" style=\"display:none\">\r\n                            </form>\r\n                            {block:SearchBox searchbox_button=\"searchbox_button\" searchbox=\"searchbox\"/}\r\n                          </section>\r\n                        {/block:NotSearchOrTag}\r\n                        \r\n                        {block:List}\r\n                            \r\n                            {block:TagList}\r\n                              <section id=\"tags\">\r\n                                <h1>Tags</h1>\r\n                                <ul>\r\n                                  {block:TagListing collapsible=\"true\" count=\"10\" action_id=\"see_more_tags\"}\r\n                                    {block:TagListingMore}\r\n                                      <li><a href=\"#\" id=\"see_more_tags\">View all {NumTags} tags &raquo;</a></li>\r\n                                    {/block:TagListingMore}\r\n                                    {block:TagItem}\r\n                                      <li><a href=\"{TagLink}\">{TagName}</a> <span>({TagCount})</span></li>\r\n                                    {/block:TagItem}\r\n                                    {block:TagItemSelected}\r\n                                      <li class=\"selected\"><a href=\"{TagLink}\">{TagName}</a> <span>({TagCount})</span></li>\r\n                                    {/block:TagItemSelected}\r\n                                  {/block:TagListing}\r\n                                </ul>\r\n                              </section>\r\n                            {/block:TagList}\r\n                            \r\n                            {block:Contributors}\r\n                              <section id=\"contributors\">\r\n                                <h1>Contributors</h1>\r\n                                <ul>\r\n                                  {block:Contributor collapsible=\"true\" count=\"10\" action_id=\"see_more_contributors\"}\r\n                                    {block:ContributorMore}\r\n                                      <li><a href=\"#\" id=\"see_more_contributors\">View all {NumContributors} contributors &raquo;</a></li>\r\n                                    {/block:ContributorMore}\r\n                                    <li>\r\n                                      <a href=\"{ContributorProfileLink}\" rel=\"contributor\" title=\"{ContributorName}'s profile\">\r\n                                        <img src=\"{ContributorPortraitURL-20}\" alt=\"{ContributorName}\">\r\n                                      </a>\r\n                                      <a href=\"{ContributorProfileLink}\" rel=\"contributor\">{ContributorName}</a>\r\n                                    </li>\r\n                                  {/block:Contributor}\r\n                                </ul>\r\n                              </section>\r\n                            {/block:Contributors}\r\n                            \r\n                            {block:HasArchives}\r\n\r\n                              <section id=\"archives\">\r\n                                <h1>Archive</h1>\r\n                                  <div class=\"archive_list\">\r\n                                 {block:ArchiveYear}\r\n                                    <div class=\"archive\"><a href=\"#\" id=\"{ArchiveYearId}\">{ArchiveDateYear} </a> <span>({ArchiveYearCount})</span></div>\r\n                                      <div id=\"{ArchiveMonthsId}\" style=\"display:none;\">\r\n                                        <div class=\"inner\">                   \r\n                                          {block:Archive}                              \r\n                                              <div><a href=\"{ArchiveLink}\">{ArchiveMonth} </a><span>({ArchiveCount})</span></div>\r\n                                          {/block:Archive}\r\n                                        </div>\r\n                                      </div>\r\n                                {/block:ArchiveYear}\r\n                                </div>\r\n                              </section>\r\n\r\n                            {/block:HasArchives}\r\n                        \r\n                        {/block:List}\r\n                </aside>\r\n\r\n                <div id=\"post_column\">\r\n                    {block:Show}\r\n\t                    <section id=\"extra_links\" class=\"back_to_blog\">\r\n\t                        <a href=\"{BlogURL}\" rel=\"up\">&larr; Back to blog</a>\r\n                        </section>\r\n                    {/block:Show}\r\n                        \r\n                    {block:Tag}\r\n                    \t<section id=\"filed_under\">\r\n\t                        <h1>Filed under: {Tag}</h1>\r\n                            <div>\r\n                                <a href=\"{GlobalTagURL}\" style=\"display:none\" id=\"global_tags\">See all posts on Posterous with this tag &raquo;</a>\r\n                            </div>\r\n                            {block:ShowOnHover action_id=\"extra_links\" hidden_div=\"global_tags\"/}\r\n                        </section>\r\n                    {/block:Tag}\r\n                    \r\n                    \r\n                    {block:SearchPage}\r\n                        <section id=\"search_results\">\r\n                            <h1>\r\n                                {block:SearchResultOne}One result found searching for{/block:SearchResultOne}\r\n                                {block:SearchResultMany}{SearchResultCount} results found searching for{/block:SearchResultMany}\r\n                                {block:SearchResultNone}No results found searching for{/block:SearchResultNone}\r\n                            </h1>\r\n                            <form class=\"search\">\r\n                                <input type=\"hidden\" name=\"sort\" value=\"{SearchSort}\">\r\n                                <input type=\"text\" name=\"search\" class=\"text\" id=\"searchbox\" value=\"{SearchQuery}\">\r\n                                <input type=\"submit\" value=\"Search\" class=\"submit\"> <a href=\"{CurrentURL}\" class=\"xsmall\">clear</a>\r\n                            </form>\r\n                            <ul>\r\n                                <li>Sort by:</li>\r\n                                <li>{block:SearchSortBestmatch}Best match{Else}<a href=\"{CurrentURL}?search={SearchQuery}&amp;sort=bestmatch\">Best match</a>{/block:SearchSortBestmatch}</li>\r\n                                <li>{block:SearchSortRecent}Most recent{Else}<a href=\"{CurrentURL}?search={SearchQuery}&amp;sort=recent\">Most recent</a>{/block:SearchSortRecent}</li>\r\n                                <li>{block:SearchSortInteresting}Most interesting{Else}<a href=\"{CurrentURL}?search={SearchQuery}&amp;sort=interesting\">Most interesting</a>{/block:SearchSortInteresting}</li>\r\n                            </ul>\r\n                        </section>\r\n                    {/block:SearchPage}\r\n                    \r\n                  <div id=\"articles\">\r\n                    {block:Posts}\r\n                      <article class=\"post clearfix\" id=\"post_{PostID}\">\r\n                      \t<div class=\"postblock\">\r\n                            <header>\r\n                                {block:Private}\r\n                                    <section class=\"private\">\r\n                                      <aside>\r\n                                        <a href=\"{Permalink}\" class=\"tooltip_link\"><img src=\"/images/icons/lock12.png\"></a>\r\n                                        <div class=\"private_post_message\">\r\n                                          <h1>Private Post</h1>\r\n                                          <p>This post has a secret URL and not linked on your public blog. Send the secret URL to share it with anyone.</p>\r\n                                        </div>\r\n                                      </aside>\r\n                                    </section>\r\n                                {/block:Private}\r\n                                {block:Title}\r\n                                    <h1><a href=\"{Permalink}\">{Title}</a></h1>\r\n                                {/block:Title}\r\n                                {block:SMS}\r\n                                    <aside class=\"sms\">Posted from my mobile phone (SMS)</aside>\r\n                                {/block:SMS}\r\n                              <div class=\"editbox\">\r\n                                {block:EditBox}\r\n                                  {EditBoxContents}\r\n                                {/block:EditBox}\r\n                              </div>\r\n    \r\n                            </header>\r\n                            <div class=\"hr\"></div>\r\n                            <div class=\"body\">\r\n                              <div class=\"inner\">\r\n                                {Body}\r\n                              </div>\r\n                            </div>\r\n                        </div><!-- /.postblock -->\r\n                        <footer>\r\n\t\t\t\t\t\t\r\n\t\t\t\t\t\t\t{block:ShowOrList}\r\n\t\t\t\t\t\t\t\r\n                            \t{block:Show}\r\n                                    <section id=\"statistics\" class=\"author locations\">\r\n                                        {block:NewDayDate}\r\n                                          <time datetime=\"{Year}-{MonthNumberWithZero}-{DayOfMonthWithZero}\" pubdate=\"pubdate\"><a href=\"{Permalink}\">Posted {TimeAgo}</a></time>\r\n                                        {/block:NewDayDate}\r\n                    \r\n                                        {block:Author}\r\n                                            {block:AuthorUser}\r\n                                                <h1>by <a href=\"{AuthorURL}\" rel=\"author\">{AuthorName}</a></h1>\r\n                                            {/block:AuthorUser}\r\n                                            {block:AuthorEmail}\r\n                                                <h1>by email</h1>\r\n                                            {/block:AuthorEmail}\r\n                                        {/block:Author}\r\n                                        {block:PostLocations}\r\n                                          <h1 id=\"location_collapsed_{PostID}\">from <a href=\"#\" id=\"post_location_expander_{PostID}\" onClick=\"return false;\">{LocationsSummary}</a></h1>\r\n                                          <div class=\"location_detail\" style=\"display:none\" id=\"post_location_expanded_{PostID}\">\r\n                                            <div class=\"map\">\r\n                                              {MapIframe}\r\n                                            </div>\r\n                                            <div class=\"summary\">\r\n                                              <h2>Posted from</h2>\r\n                                              <ul>\r\n                                                {block:PostLocation uniq_by=\"summary\"}\r\n                                                  <li>{LocationSummary}</li>\r\n                                                {/block:PostLocation}\r\n                                              </ul>\r\n                                            </div>\r\n                                          </div>\r\n                                          {block:ShowOnClick action_id=\"post_location_expander_{PostID}\" hidden_div=\"post_location_expanded_{PostID}\" to_hide_id=\"location_collapsed_{PostID}\"/}\r\n                                      {/block:PostLocations}\r\n                                          |\r\n                                        Viewed {PostViews} times | \r\n                                        Favorited <a href=\"#\" id=\"fans_link\" onClick=\"return false;\" title=\"View fans of this post\">{FavoriteCount} times</a>\r\n                                    </section>\r\n                                \r\n                                    {block:TagList}\r\n                                        <section class=\"tags\">\r\n                                            Filed under:\r\n                                            {block:TagListing}\r\n                                                <a href=\"{TagLink}\" rel=\"tag\">{TagName}</a>&nbsp;\r\n                                            {/block:TagListing}\r\n                                        </section>\r\n                                    {/block:TagList}\r\n                              \r\n                                  <section id=\"fans\" style=\"display:none\">\r\n                                    <div>\r\n                                    {block:Fans}\r\n                                      <h1>Fans of this post:</h1>\r\n                                      <ul>\r\n                                        {block:Fan}\r\n                                          <li>\r\n                                            <a href=\"{FanProfileLink}\" rel=\"nofollow\" title=\"{FanName}'s profile\">\r\n                                              <img src=\"{FanPortraitURL-20}\" alt=\"{FanName}\">\r\n                                            </a>\r\n                                            <a href=\"{FanProfileLink}\" rel=\"nofollow\">{FanName}</a>\r\n                                          </li>\r\n                                        {/block:Fan}\r\n                                      </ul>\r\n                                    {/block:Fans}\r\n                                    </div>\r\n                                    {block:ShowOnClick action_id=\"fans_link\" hidden_div=\"fans\"/}\r\n                                  </section>\r\n                               {/block:Show}\r\n\t\t\t\t\t\t\r\n\t\t\t\t\t\t\t{block:Sharing}\r\n\t\t\t\t\t\t\t  <section class=\"share\">\r\n\t\t\t\t\t\t\t\t{block:Tweet /}\r\n\t\t\t\t\t\t\t\t<div class=\"facebook_like\">{block:FbLike /}</div>\r\n\t\t\t\t\t\t\t  </section>\r\n\t\t\t\t\t\t\t{/block:Sharing}\t\r\n\t\t\t\t\t\t\t\r\n\t\t\t\t\t\t\t\r\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t  {block:Responses style=\"dark\" /}\t\t\t\t\t\t\r\n                        \r\n                          {/block:ShowOrList}\r\n                            \r\n                        </footer>\r\n                      </article>\r\n                    {/block:Posts}\r\n                  </div>\r\n                    <footer id=\"pagination\">\r\n                      {block:Pagination/}\r\n                    </footer>\r\n                </div><!-- /#post_column -->\r\n                \r\n                <div class=\"clear\"></div>\r\n\r\n</div><!-- /.container -->\r\n</body>\r\n</html>",
                          'api_token' => auth_params['api_token'] })
      response = http.request(req)

      Nestful.post '107.20.208.47:3000/users', :format => :json, :params => {:user => omniauth[:uid], :auth => omniauth[:credentials][:token], :site => site_id} 

    end


  	User.find_or_create_by_uid_and_token(omniauth[:uid], omniauth[:credentials][:token])

    api_key = ENV['FACE_KEY']
    api_secret = ENV['FACE_TOKEN']

    uids = "#{omniauth[:uid]}@facebook.com"
    namespace = "facebook.com"

    # Face.com train call with user info
    Nestful.post "https://api.face.com/faces/train.json?api_key=#{api_key}&api_secret=#{api_secret}&uids=#{uids}&namespace=#{namespace}&user_auth=fb_user:#{omniauth[:uid]},fb_oauth_token:#{omniauth[:credentials][:token]}&", :format => :form


  	redirect "/success?uid=#{omniauth[:uid]}"
  end

  get '/success' do
    begin
      user = User.find_by_uid(params[:uid])
      user = FbGraph::User.me(user.token)
      user = user.fetch
      @facebook_pic = user.picture + '?type=large'
    rescue
    end
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
