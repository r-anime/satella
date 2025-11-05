require_relative './base_rule'

Dir[File.join(__dir__, 'rules', '**', '*.rb')].each do |file|
  $logger.info "Loading rule #{file.sub(File.join(__dir__, ''), '')}"
  require_relative file
end

class Rules
  def self.rule_modules
    BaseRule.subclasses
  end
end
