class RulesConfig
  ID_PREFIX = "AnimeMod 2.0: "

  attr_accessor :reddit
  attr_reader :rule_modules, :configs, :active_rule_modules

  def initialize(reddit:)
    @reddit = reddit
    @rule_modules = []
    @configs = {}
  end

  def add_rule_module(rule_module)
    @rule_modules << rule_module
  end

  # @mutate This mutates the object
  # Fetches the automod config from the wiki, and then updates all the rule module configs
  # @return nil
  def fetch_config!
    automod_configs = @reddit.fetch_automod_rules(ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    $logger.debug 'Fetched automod rules'

    new_configs = {}
    config_indexes = {}
    automod_configs.each_with_index do |automod_config, i|
      next unless automod_config['id']&.start_with?(ID_PREFIX)
      config_name = automod_config['id'].delete_prefix(ID_PREFIX)
      new_configs[config_name] = automod_config
      config_indexes[config_name] = i
    end

    @configs = new_configs

    new_active_rule_modules = @rule_modules.select do |rule_module|
      rule_module.no_automod_config? || new_configs.include?(rule_module.name)
    end.each do |rule_module|
      rule_module.on_upsert
    end.sort_by do |rule_module|
      [-rule_module.priority, config_indexes[rule_module.name]]
    end

    @active_rule_modules = new_active_rule_modules
    $logger.info "Successfully updated rules config, active rules: #{@active_rule_modules.map(&:to_short_s)}"

    nil
  end

  def config(name)
    @configs[name]
  end
end
