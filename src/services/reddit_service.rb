require 'redd'
require 'yaml'
require 'json'

class RedditService
  MAX_REPORT_REASON_LENGTH = 100

  attr_reader :redd
  extend Forwardable
  def_delegators :client, :request, :get, :post, :put, :patch, :delete
  attr_accessor :rules_config

  def initialize(user_agent:, client_id:, secret:, username:, password:)
    @redd = Redd.it(user_agent:, client_id:, secret:, username:, password:)
    $logger.info { "Successfully authed to reddit" }
  end

  def fetch_automod_rules(subreddit)
    YAML.load_stream(fetch_wiki_page("config/automoderator", subreddit:)[:data][:content_md])
  end

  def fetch_toolbox(subreddit)
    JSON.parse(fetch_wiki_page("toolbox", subreddit:)[:data][:content_md], symbolize_names: true)
  end

  # combined actions

  def edit_post(id36, content)
    edit_user_text("t3_#{id36}", content)
  end

  def edit_comment(id36, content)
    edit_user_text("t1_#{id36}", content)
  end

  def disable_inbox_replies(fullname)
    inbox_replies(fullname, false)
  end

  def enable_inbox_replies(fullname)
    inbox_replies(fullname, true)
  end

  def remove_with_reason(fullname, reason, sticky: false, how: 'yes', spam: false, lock: true,
                         header: @rules_config.removal_header(fullname), footer: @rules_config.removal_footer(fullname))
    reason = header + reason if header
    reason = reason + footer if footer
    remove(fullname)
    comment_json = reply_comment(fullname, reason)
    reply_id = comment_json[:json][:data][:things][0][:data][:name]
    lock(reply_id) if lock
    distinguish(reply_id, sticky:)
  end

  def mod_comment(fullname, comment_text, sticky: false, how: 'yes', reply_notifications: nil)
    comment_json = reply_comment(fullname, comment_text)
    reply_fullname = comment_json[:json][:data][:things][0][:data][:name]
    distinguish(reply_fullname, sticky:)
    inbox_replies(reply_fullname, reply_notifications) if reply_notifications
  end

  # direct api

  def distinguish(fullname, sticky: false, how: 'yes')
    post("/api/distinguish", {
      api_type: 'json',
      id: fullname,
      how:,
      sticky:,
    }).body
  end

  def edit_user_text(fullname, text)
    post("/api/editusertext", {
      api_type: 'json',
      thing_id: fullname,
      text:
    }).body
  end

  def inbox_replies(fullname, state)
    post("/api/sendreplies", {
      api_type: 'json',
      id: fullname,
      state:
    }).body
  end

  def lock(fullname)
    post("/api/lock", {
      api_type: 'json',
      id: fullname
    }).body
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

  def report(fullname, reason)
    post("/api/report", {
      api_type: 'json',
      thing_id: fullname,
      reason: reason.truncate(MAX_REPORT_REASON_LENGTH, omission: '…')
    }).body
  end

  def set_default_comment_sort(fullname, sort)
    post("/api/set_suggested_sort", {
      api_type: 'json',
      id: fullname,
      sort: sort
    }).body

  end

  # Mod notes
  def create_mod_note(username, label, message, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'], reddit_id: nil)
    post("/api/mod/notes", {
      user: username,
      note: message,
      label:,
      reddit_id:,
      subreddit:,
    }).body
  end

  def fetch_mod_notes(username, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'], limit: 100, filter: 'all')
    get("/api/mod/notes", {
      user: username,
      subreddit:,
      limit:,
      filter:,
    }).body
  end

  # Widgets
  def fetch_widgets(subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    get("/r/#{subreddit}/api/widgets").body
  end

  def create_widget(widget_json, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    post("/r/#{subreddit}/api/widget", {
      json: widget_json.to_json
    }).body
  end

  def update_widget(widget_id, widget_json, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    put("/r/#{subreddit}/api/widget/#{widget_id}", {
      json: widget_json.to_json
    }).body
  end

  def update_widget_order(widget_section, widget_order_json, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    patch("/r/#{subreddit}/api/widget_order/#{widget_section}", {
      json: widget_order_json.to_json
    }).body
  end

  def delete_widget(widget_id, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    delete("/r/#{subreddit}/api/widget/#{widget_id}").code # code cause no response body
  end

  # Wiki
  def fetch_wiki_page(page_path, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    get(File.join("/r/#{subreddit}/wiki/", page_path)).body
  end

  def edit_wiki_page(page_path, page_content, subreddit: ENV['SUBREDDIT_NAME_TO_ACT_ON'], previous_revision: nil, reason: nil)
    post("/r/#{subreddit}/api/wiki/edit", {
      page: page_path,
      content: page_content,
      reason: reason,
      previous: previous_revision
    }).body
  end

  private

  def client
    @redd.client
  end
end
