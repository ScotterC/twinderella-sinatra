require 'sinatra'
require 'sinatra/activerecord'

# Establish the database connection; or, omit this and use the DATABASE_URL
# environment variable or the default sqlite://<environment>.db as the connection string:
set :database,  (ENV["DATABASE_URL"] || "sqlite3:///#{Dir.pwd}/development.sqlite3")

# # At this point, you can access the ActiveRecord::Base class using the
# # "database" object:
# puts "the users table doesn't exist" if !database.table_exists?('users')

# # models just work ...
# class User < ActiveRecord::Base
# end

# # see:
# User.all

# # access the models within the context of an HTTP request
# get '/foos/:id' do
#   @foo = Foo.find(params[:id])
#   erb :foos
# end