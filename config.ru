require File.expand_path('../app', __FILE__)

use Rack::Session::Cookie

if ENV['RACK_ENV'] == 'development'
		use OmniAuth::Builder do
		  provider :facebook, '282199255185714', '7d72c63099ff31cac1fdeb2814d24447', :scope => SCOPE
		end
else
	use OmniAuth::Builder do
	  provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET'], :scope => SCOPE
	end
end



run App.new
