require 'httparty'
require 'json'

class DiscordService
  attr_accessor :rules_config

  def initialize
    @enabled = ENV["DISCORD_ENABLED"]&.downcase == "true"
    @webhook_url = ENV["DISCORD_WEBHOOK_URL"]
    @post_webhook_url = ENV["DISCORD_POST_WEBHOOK_URL"]
    @mod_log_webhook_url = ENV["DISCORD_MOD_LOG_WEBHOOK_URL"]
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
end
