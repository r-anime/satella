require 'dotenv/load'

require_relative './src/logger'
require_relative './src/services/rabbit_service'
require_relative './src/services/reddit_service'
require_relative './src/db'
require_relative './src/rules_config'
require_relative './src/rules'

# DONE connect to rabbitmq
# DONE retries for rabbitmq
# DONE test on stage
# DONE implement auto update for rules (reddit:  "details": "Updated AutoModerator configuration", "action": "wikirevise")
# MOSTLY DONE implement main loop
# DONE implement easy removal and report methods
# TODO implement SMC (only on posts from tomorrow)
# TODO implement isekai quartet SMC
# TODO implement Source keyword checking
def main
  reddit = RedditService.new(
    user_agent: ENV['REDDIT_USER_AGENT'],
    client_id: ENV['REDDIT_CLIENT_ID'],
    secret: ENV['REDDIT_SECRET'],
    username: ENV['REDDIT_USERNAME'],
    password: ENV['REDDIT_USER_PASSWORD']
  )
  rule_modules = BaseRule.subclasses.map do |rule|
    rule.new(reddit)
  end
  rules_config = RulesConfig.new(reddit, rule_modules)
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
  $logger.debug "[posts] Received: #{message}"
  # TODO: implement your post-handling logic here
end

def handle_comment(active_rule_modules, message)
  $logger.debug "[comments] Received: #{message}"
  # TODO: implement your comment-handling logic here
end

def handle_mod_action(active_rule_modules, message)
  $logger.debug "[mod_actions] Received: #{message}"

  active_rule_modules
    .select { |rule_module| rule_module.static_mod_action_check?(message) }
    .map { |rule_module| rule_module.mod_action_check(message) }
end

main
