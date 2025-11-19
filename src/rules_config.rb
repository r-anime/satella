require 'set'
require_relative './models/user'

class RulesConfig
  ID_PREFIX = "AnimeMod 2.0: "

  attr_accessor :reddit
  attr_reader :rule_modules, :configs, :active_rule_modules, :mods

  def initialize(reddit:)
    @reddit = reddit
    @rule_modules = []
    @configs = {}
    @mods = Set.new
  end

  def add_rule_module(rule_module)
    @rule_modules << rule_module
  end

  def start_up!
    fetch_config!
    fetch_mods!
  end

  # @mutate This mutates the object
  # Fetches the automod config from the wiki, and then updates all the rule module configs
  # @return nil
  def fetch_config!
    automod_configs = @reddit.fetch_automod_rules(ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    $logger.debug 'Fetched automod rules'

    new_configs = {}
    config_indexes = {}
    automod_configs.compact.each_with_index do |automod_config, i|
      next unless automod_config['id']&.start_with?(ID_PREFIX)
      config_name = automod_config['id'].delete_prefix(ID_PREFIX)
      new_configs[config_name] = automod_config
      config_indexes[config_name] = i
    end

    @configs = new_configs

    new_active_rule_modules = @rule_modules.select do |rule_module|
      rule_module.no_automod_config? || new_configs.include?(rule_module.name)
    end.each do |rule_module|
      rule_module.base_on_upsert
      rule_module.on_upsert
    end.sort_by do |rule_module|
      [-rule_module.priority, config_indexes[rule_module.name]]
    end

    @active_rule_modules = new_active_rule_modules
    $logger.info "Successfully updated rules config, active rules: #{@active_rule_modules.map(&:to_short_s)}"

    nil
  end

  # @mutate This mutates the object
  # Fetches the current mod list from the DB
  # @return nil
  def fetch_mods!
    @mods = User.where(moderator: true).pluck(:username).to_set
    $logger.info "Successfully updated mods: #{@mods}"

    nil
  end

  def removal_header(fullname)
    "Sorry, your submission has been removed.\n\n"
  end

  def bot_footer
    "\n\n*I am a bot, and this action was performed automatically. Please [contact the moderators of this subreddit](/message/compose/?to=/r/#{ENV["SUBREDDIT_NAME_TO_ACT_ON"]}) if you have any questions or concerns.*"
  end

  def config(name)
    @configs[name]
  end
end
