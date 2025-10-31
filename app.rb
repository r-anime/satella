require 'dotenv/load'
require 'redd'
require_relative './src/db'

opts = {
  user_agent: ENV['REDDIT_USER_AGENT'],
  client_id: ENV['REDDIT_CLIENT_ID'],
  secret: ENV['REDDIT_SECRET'],
  username: ENV['REDDIT_USERNAME'],
  password: ENV['REDDIT_USER_PASSWORD']
}

reddit = Redd.it(**opts)
resp = reddit.client.get('/api/v1/me', nocache: true)
puts "resp: #{resp.body.to_json}"
