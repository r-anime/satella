require 'httparty'
require 'json'

class DiscordService
  attr_accessor :rules_config, :urgent_messages

  URGENT_MESSAGE_PING = ENV['DISCORD_URGENT_MESSAGE_PING']&.downcase == "true" ? "@here" : ""
  URGENT_MESSAGE_HEADER = "#{URGENT_MESSAGE_PING} **Urgent message from Satella** (r/#{ENV['SUBREDDIT_NAME_TO_ACT_ON']})"
  URGENT_MESSAGE_FOOTER = "*Aishiteru*"

  def initialize
    @enabled = ENV["DISCORD_ENABLED"]&.downcase == "true"
    @webhook_url = ENV["DISCORD_WEBHOOK_URL"]
    @post_webhook_url = ENV["DISCORD_POST_WEBHOOK_URL"]
    @mod_log_webhook_url = ENV["DISCORD_MOD_LOG_WEBHOOK_URL"]
    @sub_urgent_message_webhook_url = ENV["DISCORD_SATELLA_URGENT_MESSAGE_WEBHOOK_URL"]

    @urgent_messages = []
    $logger.info { "Discord is #{@enabled ? 'enabled' : 'disabled'}" }
  end

  def post_webhook(payload)
    return unless @enabled

    HTTParty.post(
      @webhook_url,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {embeds: payload}.to_json
    )
  end

  def post_post_webhook(payload)
    return unless @enabled

    HTTParty.post(
      @post_webhook_url,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {embeds: payload}.to_json
    )
  end

  def post_mod_log_webhook(payload)
    return unless @enabled

    HTTParty.post(
      @mod_log_webhook_url,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {embeds: payload}.to_json
    )
  end

  def post_urgent_message_webhook(message, force: false)
    return unless @enabled || force

    HTTParty.post(
      # @sub_mod_main_webhook_url,
      @sub_urgent_message_webhook_url,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {content: message}.to_json
    )
  end

  def add_urgent_message!(message)
    $logger.warn { "Urgent message from Satella to Discord appended: \"#{message}\"" }
    @urgent_messages << message
  end

  def flush_urgent_messages!
    return false if @urgent_messages.empty?

    message_text = URGENT_MESSAGE_HEADER + "\n\n" + @urgent_messages.map.with_index(1) do |message, index|
      "**Message #{index}**: #{message}"
    end.join("\n\n") + "\n\n" + URGENT_MESSAGE_FOOTER
    post_urgent_message_webhook(message_text, force: true)

    $logger.warn { "#{@urgent_messages.size} Urgent messages from Satella to Discord flushed" }
    clear_urgent_messages!
    true
  end

  def clear_urgent_messages!
    @urgent_messages = []
  end
end
