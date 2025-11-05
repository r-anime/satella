require 'redd'
require 'yaml'

class RedditService
  attr_reader :redd
  extend Forwardable
  def_delegators :client, :request, :get, :post, :put, :patch, :delete

  def initialize(user_agent:, client_id:, secret:, username:, password:)
    @redd = Redd.it(user_agent:, client_id:, secret:, username:, password:)
    $logger.info "Successfully authed to reddit"
  end

  def fetch_automod_rules(subreddit)
    YAML.load_stream(get("/r/#{subreddit}/wiki/config/automoderator").body[:data][:content_md])
  end

  private

  def client
    @redd.client
  end
end
