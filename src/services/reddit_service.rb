require 'redd'
require 'yaml'

class RedditService
  MAX_REPORT_REASON_LENGTH = 100

  attr_reader :redd
  extend Forwardable
  def_delegators :client, :request, :get, :post, :put, :patch, :delete
  attr_accessor :rules_config

  def initialize(user_agent:, client_id:, secret:, username:, password:)
    @redd = Redd.it(user_agent:, client_id:, secret:, username:, password:)
    $logger.info "Successfully authed to reddit"
  end

  def fetch_automod_rules(subreddit)
    YAML.load_stream(get("/r/#{subreddit}/wiki/config/automoderator").body[:data][:content_md])
  end

  def report(fullname, reason)
    post("/api/report", {
      api_type: 'json',
      thing_id: fullname,
      reason: reason.truncate(MAX_REPORT_REASON_LENGTH, omission: '…')
    }).body
  end

  # TODO integrate with removal reasons template
  def remove_with_reason(fullname, reason, sticky: false, how: 'yes', spam: false,
                         header: @rules_config.removal_header(fullname), footer: @rules_config.bot_footer)
    reason = header + reason if header
    reason = reason + footer if footer
    remove(fullname)
    comment_json = reply_comment(fullname, reason)
    reply_id = comment_json[:json][:data][:things][0][:data][:name]
    distinguish(reply_id, sticky:)
  end

  def mod_comment(fullname, comment_text, sticky: false, how: 'yes')
    comment_json = reply_comment(fullname, comment_text)
    reply_id = comment_json[:json][:data][:things][0][:data][:name]
    distinguish(reply_id, sticky:)
  end

  def remove(fullname, spam: false)
    post("/api/remove", {
      api_type: 'json',
      id: fullname,
      spam:
    }).body
  end

  def reply_comment(parent_fullname, text)
    post("/api/comment", {
      api_type: 'json',
      text:,
      thing_id: parent_fullname
    }).body
  end

  def distinguish(fullname, sticky: false, how: 'yes')
    post("/api/distinguish", {
      api_type: 'json',
      id: fullname,
      how:,
      sticky:,
    }).body
  end

  private

  def client
    @redd.client
  end
end
