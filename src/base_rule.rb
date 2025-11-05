class BaseRule
  attr_reader :reddit
  attr_accessor :rules_config

  def initialize(reddit)
    @reddit = reddit
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
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_post_check?(_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast true
  # A hook for static comment eligibility to be run.
  # There should be no long processing like a DB call or an API call in this.
  # This is just to determine if it remotely makes sense to run the checker for this given the existing data.
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_comment_check?(_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast true
  # A hook for static mod action eligibility to be run.
  # There should be no long processing like a DB call or an API call in this.
  # This is just to determine if it remotely makes sense to run the checker for this given the existing data.
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return true if the main checker should be invoker
  def static_mod_action_check?(_message)
    false
  end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual post rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return nil at the moment. For now, it should use direct side effects to achieve it's effects. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in their own function.
  def post_check(_message) end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual comment rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return nil at the moment. For now, it should use direct side effects to achieve it's effects. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in their own function.
  def comment_check(_message) end

  # @overridable true
  # @parallel false
  # @fast false
  # A hook for the actual mod action rule check.
  # This can use DB calls or API requests to do so.
  # Eventually it will be run in parallel, but currently it is run in sequence.
  # @param message The rabbitmq message with the reddit and db object in json form
  # @return nil at the moment. For now, it should use direct side effects to achieve it's effects. Eventually it will return a custom object detailing what action it would like to take, and letting the main loop take care of combining them all and doing it at the end. For now, put all result effect in their own function.
  def mod_action_check(_message) end

  def inspect
    attrs = [:name, :priority, :config]
              .map do |attr| "#{attr}=#{send(attr).inspect}" end
              .join(', ')
    "#<#{self.class} #{attrs}>"
  end
end
