require_relative './base_rule'

Dir[File.join(__dir__, 'rules', '**', '*.rb')].each do |file|
  $logger.info { "Loading rule #{file.sub(File.join(__dir__, ''), '')}" }
  require_relative file
end

module Rules
  def self.rule_modules
    @@rule_modules ||= BaseRule.descendants.map do |rule_module|
      [rule_module.name, rule_module]
    end.to_h
  end

  def self.non_automod_rule_modules
    rule_modules.values.select do |rule_module|
      rule_module.no_automod_config?
    end
  end
end
