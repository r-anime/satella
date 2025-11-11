require 'dotenv/load'

require_relative './src/logger'
require_relative './src/services/rabbit_service'
require_relative './src/services/reddit_service'
require_relative './src/db'
require_relative './src/rules_config'
require_relative './src/rules'

def main
  reddit = RedditService.new(
    user_agent: ENV['REDDIT_USER_AGENT'],
    client_id: ENV['REDDIT_CLIENT_ID'],
    secret: ENV['REDDIT_SECRET'],
    username: ENV['REDDIT_USERNAME'],
    password: ENV['REDDIT_USER_PASSWORD']
  )

  rules_config = RulesConfig.new(reddit:)
  rule_modules = Rules.rule_modules.map do |rule|
    rule.new(reddit:, rules_config:)
  end
  rules_config.fetch_config!

  $logger.info "active rules: #{rules_config.active_rule_modules.map { |rm| "#{rm.name}: #{rm.priority}" }}"

  rabbit = RabbitService.new(
    host: ENV['RABBITMQ_HOST'],
    port: ENV['RABBITMQ_PORT'],
    username: ENV['RABBITMQ_USER'],
    password: ENV['RABBITMQ_PASS'],
    vhost: ENV['RABBITMQ_VHOST'],
    retry_exchange_name: "#{ENV['RABBITMQ_EXCHANGE']}.#{ENV['RABBITMQ_RETRY_EXCHANGE_PREFIX']}",
    queues: get_queues(rules_config.active_rule_modules),
    log_level: ENV['LOG_LEVEL_CONSOLE']
  )

  rabbit.listen!
end

def get_queues(active_rule_modules)
  missing = []
  queues = ENV.select { |k, _| k.start_with?(RabbitService::RABBIT_QUEUE_ENV_PREFIX) }
              .transform_keys { |k| k.delete_prefix(RabbitService::RABBIT_QUEUE_ENV_PREFIX).downcase.to_sym }
              .map do |queue_key, queue_name|
    handler_name = "handle_#{queue_key.to_s.singularize}"
    missing << handler_name unless respond_to?(handler_name, true)
    [queue_key, {queue_name: queue_name, handler: method(handler_name).curry.call(active_rule_modules)}] if respond_to?(handler_name, true)
  end.compact.to_h

  raise NoMethodError, "Missing handler methods: #{missing.join(', ')}" if missing.any?

  queues
end

def handle_post(active_rule_modules, message)
  if $logger.level <= Logger::DEBUG
    $logger.info "[posts] Received: #{message["reddit"]["id"]}"
  else
    $logger.debug "[posts] Received: #{message}"
  end

  results = active_rule_modules
              .select { |rule_module| rule_module.static_post_check?(message) }
              .map { |rule_module| rule_module.post_check(message) }
              .reject { |rule_result| rule_result.is_a?(RuleResult::NoAction) }
  # TODO actually process and merge results into generic grand action
  results.each { |rule_result| rule_result.rule_module.execute_post(rule_result) }
end

def handle_comment(active_rule_modules, message)
  if $logger.level <= Logger::DEBUG
    $logger.info "[comments] Received: #{message["reddit"]["id"]}"
  else
    $logger.debug "[comments] Received: #{message}"
  end

  results = active_rule_modules
              .select { |rule_module| rule_module.static_comment_check?(message) }
              .map { |rule_module| rule_module.comment_check(message) }
              .reject { |rule_result| rule_result.is_a?(RuleResult::NoAction) }
  # TODO actually process and merge results into generic grand action
  results.map { |rule_result| rule_result.rule_module.execute_comment(rule_result) }
end

def handle_mod_action(active_rule_modules, message)
  if $logger.level <= Logger::DEBUG
    $logger.info "[mod_actions] Received: #{message["reddit"]["id"]}"
  else
    $logger.debug "[mod_actions] Received: #{message}"
  end

  results = active_rule_modules
              .select { |rule_module| rule_module.static_mod_action_check?(message) }
              .map { |rule_module| rule_module.mod_action_check(message) }
              .reject { |rule_result| rule_result.is_a?(RuleResult::NoAction) }
  # TODO actually process and merge results into generic grand action
  results.map { |rule_result| rule_result.rule_module.execute_mod_action(rule_result) }
end

main
