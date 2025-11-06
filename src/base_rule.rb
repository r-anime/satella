require_relative './rule_result'

class BaseRule
  attr_reader :reddit
  attr_accessor :rules_config

  def initialize(reddit:, rules_config:)
    @reddit = reddit
    @rules_config = rules_config
    rules_config.add_rule_module(self)
  end

  # @abstract true
  # @fast true
  # The name of the rule (without the prefix), to be matched against the id field in automod config
  # @return string
  def name
    raise NotImplementedError, "#{self.class} must implement #name"
  end

  # @abstract true
  # @parallel false
  # @fast false
  # a hook to run when the rules are initialized or updated
  # this should be the sole initialization of (automod based) config for a rule module
  # @return nil
  def on_upsert
    raise NotImplementedError, "#{self.class} must implement #on_upsert"
  end

  # @fast true
  # gets the config for the given rule module
  # @return nil if there is no automod config for the rule module
  # @return the automod config in json form if it exists
  def config
    rules_config.config(name)
  end

  # @fast true
  # gets the priority of the rule for the order they should be processed in
  # @return integer
  def priority
    config&.[]('priority') || 0
  end

  # @overridable true
  # @parallel false
  # Use this if it should always be active and doesn't have an automod config
  # This is mainly for internal use only, for rules like the RuleUpdaterRule
  # @return boolean
  def no_automod_config?
    false
  end

  # @overridable true
  # @parallel false
  # @fast true
  # A hook for static post eligibility to be run.
  # There should be no long processing like a DB call or an API call in this.
  # This is just to determine if it remotely makes sense to run the checker for this given the existing data.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_post_check?(_rabbit_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast true
  # A hook for static comment eligibility to be run.
  # There should be no long processing like a DB call or an API call in this.
  # This is just to determine if it remotely makes sense to run the checker for this given the existing data.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_comment_check?(_rabbit_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast true
  # A hook for static mod action eligibility to be run.
  # There should be no long processing like a DB call or an API call in this.
  # This is just to determine if it remotely makes sense to run the checker for this given the existing data.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_mod_action_check?(_rabbit_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual post rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # No action should be taken in this method. Those should be done in execute_post.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return args for execute_post at the moment. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in execute_post.
  def post_check(rabbit_message)
    RuleResult::NoAction.new(rule_module: self, rabbit_message:)
  end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual comment rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # No action should be taken in this method. Those should be done in execute_comment.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return args for execute_comment at the moment. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in execute_comment.
  def comment_check(rabbit_message)
    RuleResult::NoAction.new(rule_module: self, rabbit_message:)
  end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual mod action rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # No action should be taken in this method. Those should be done in execute_comment.
  # @param rabbit_message The rabbitmq message with the reddit and db object in json form
  # @return args for execute_mod_action at the moment. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in execute_mod_action.
  def mod_action_check(rabbit_message)
    RuleResult::NoAction.new(rule_module: self, rabbit_message:)
  end

  # @overridable true (you should still call super)
  # @parallel false
  # @fast false
  # For now, it should use direct side effects to achieve it's effects.
  # This will eventually be changed to just have exceptional effects (beyond the standard actions). It will only be called if the checks say that it should run.
  # @param result The RuleResult that the post_check returned
  # @return nil
  def execute_post(result)
    $logger.info do
      attrs = [:id, [:author, :name], :link_flair_text, :title]
                .map { Array(it) }.map do
        [it.map(&:to_s).join('.').to_sym, result.rabbit_message[:reddit].dig(*it)]
      end.reject { |(key, value)| !value }.to_h
      "#{self.class.name} Actioning message: #{attrs}"
    end
  end

  # @overridable true (you should still call super)
  # @parallel false
  # @fast false
  # For now, it should use direct side effects to achieve it's effects.
  # This will eventually be changed to just have exceptional effects (beyond the standard actions). It will only be called if the checks say that it should run.
  # @param result The RuleResult that the check_check returned
  # @return nil
  def execute_comment(result)
    $logger.info do
      attrs = [:id, [:author, :name], :body]
                .map { Array(it) }.map do
        [it.map(&:to_s).join('.').to_sym, result.rabbit_message[:reddit].dig(*it).truncate(300)]
      end.reject { |(key, value)| !value }.to_h
      "#{self.class.name} Actioning message: #{attrs}"
    end
    exit
  end

  # @overridable true (you should still call super)
  # @parallel false
  # @fast false
  # For now, it should use direct side effects to achieve it's effects.
  # This will eventually be changed to just have exceptional effects (beyond the standard actions). It will only be called if the checks say that it should run.
  # @param result The RuleResult that the mod_action_check returned
  # @return nil
  def execute_mod_action(result)
    $logger.info do
      attrs = [:mod_id36, :action, :details, :description].map { [it, result.rabbit_message[:reddit][it]] }.to_h
      "#{self.class.name} Actioning message: #{attrs}"
    end
  end

  def inspect
    attrs = [:name, :priority, :config]
              .map { |attr| "#{attr}=#{send(attr)&.inspect}" }
              .join(', ')
    "#<#{self.class} #{attrs}>"
  end
end
