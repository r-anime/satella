require 'set'
require_relative './models/user'

class RulesConfig
  ID_PREFIX = "AnimeMod 2.0: "

  attr_accessor :reddit, :discord, :placeholder_service, :toolbox_service, :youtube_service
  attr_reader :rule_modules, :configs, :active_rule_modules, :mods
  attr_accessor :removal_header_template, :removal_footer_template

  def initialize(reddit:, discord:, placeholder_service:, toolbox_service:, youtube_service:)
    @reddit = reddit
    @discord = discord
    @placeholder_service = placeholder_service
    @toolbox_service = toolbox_service
    @youtube_service = youtube_service

    @mods = Set.new
    @removal_header_template = "Header not loaded"
    @removal_footer_template = "Footer not loaded"
  end

  def start_up!
    fetch_config!
    fetch_mods!
  end

  # TODO add caching
  # @mutate This mutates the object
  # Fetches the automod config from the wiki, and then updates all the rule module configs
  # @return nil
  def fetch_config!
    @discord.clear_urgent_messages!
    automod_configs = @reddit.fetch_automod_rules(ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    $logger.debug { "Fetched automod rules" }

    non_automod_rule_modules = Rules.non_automod_rule_modules.map { |rm| [nil, rm] }
    rule_modules = non_automod_rule_modules + automod_configs.compact.select do |automod_config|
      automod_config['id']&.start_with?(ID_PREFIX)
    end.select do |automod_config|
      Rules.rule_modules[automod_config['id'].delete_prefix(ID_PREFIX)]
    end.map do |automod_config|
      [automod_config, Rules.rule_modules[automod_config['id'].delete_prefix(ID_PREFIX)]]
    end

    new_active_rule_modules = rule_modules.map do |automod_config, rule_module|
      rule_module.new(
        config: automod_config, reddit:, discord:, rules_config: self,
        placeholder_service:, toolbox_service:, youtube_service:,
      )
    end.select do |rule_module|
      begin
        rule_module.base_on_upsert
        rule_module.on_upsert
        true
      rescue StandardError => e
        $logger.error { "#{rule_module.name} experienced an error on upsert and has been **disabled**: #{e.inspect}\n#{e.backtrace.join("\n")}" }
        @discord.add_urgent_message!("#{rule_module.name} experienced an error on upsert and has been **disabled**: #{e.inspect}")
        false
      end
    end.each_with_index.sort_by do |rule_module, index|
      [-rule_module.priority, index]
    end.map(&:first)

    @active_rule_modules = new_active_rule_modules
    had_urgent_messages = @discord.flush_urgent_messages!
    $logger.info { "Successfully updated rules config#{had_urgent_messages ? "with urgent messages" : ""}, active rules: #{@active_rule_modules.map(&:to_short_s)}" }
    nil
  end

  # @mutate This mutates the object
  # Fetches the current mod list from the DB
  # @return nil
  def fetch_mods!
    @mods = User.where(moderator: true).pluck(:username).to_set
    $logger.info { "Successfully updated mods: #{@mods}" }

    nil
  end

  def removal_header_template=(new_header_template)
    @removal_header_template = placeholder_service.replace_template_placeholders(
      new_header_template.strip.concat("\n\n")
    )
  end

  def removal_footer_template=(new_footer_template)
    @removal_footer_template = placeholder_service.replace_template_placeholders(
      new_footer_template.strip.prepend("\n\n---\n\n")
    )
  end

  def removal_header(fullname)
    placeholder_service.replace_placeholders(@removal_header_template, fullname:)
  end

  def removal_footer(fullname)
    placeholder_service.replace_placeholders(@removal_footer_template, fullname:)
  end
end
