# require 'bundler/setup'
# require 'sinatra/base'
# require 'omniauth-facebook'
require File.expand_path('../app', __FILE__)
#require 'app'

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :facebook, '179805312129831', '5c1dcb88994d19b2bb1ea581fe518da9', :scope => SCOPE
end

run App.new
