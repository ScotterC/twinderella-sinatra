# require 'bundler/setup'
# require 'sinatra/base'
# require 'omniauth-facebook'
require File.expand_path('../app', __FILE__)
#require 'app'

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :facebook, '265707230172470', '7c3134b537fd40eb5ed5081df7dae700', :scope => SCOPE
end

run App.new
