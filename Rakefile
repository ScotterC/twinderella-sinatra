require File.expand_path('../app', __FILE__)
require 'sinatra/activerecord/rake'

require 'rubygems'
require 'bundler/setup'

namespace :jobs do
  desc "Heroku worker"
  task :work do
    exec('ruby ./tweet_filter.rb run')
  end
end
