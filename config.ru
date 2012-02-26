# require 'bundler/setup'
# require 'sinatra/base'
# require 'omniauth-facebook'
require File.expand_path('../app', __FILE__)
#require 'app'

use Rack::Session::Cookie

if ENV['RACK_ENV'] == 'development'
		use OmniAuth::Builder do
		  provider :facebook, '282199255185714', '7d72c63099ff31cac1fdeb2814d24447', :scope => SCOPE
		end
else
	use OmniAuth::Builder do
	  provider :facebook, '179805312129831', '5c1dcb88994d19b2bb1ea581fe518da9', :scope => SCOPE
	end
end

run App.new
