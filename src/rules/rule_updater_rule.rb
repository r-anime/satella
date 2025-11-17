module Rules
  class RuleUpdaterRule < BaseRule
    ACTION = 'wikirevise'
    DETAIL = 'Updated AutoModerator configuration'

    def name
      "Rule Updater Rule"
    end

    # This should not do anything
    def on_upsert
    end

    def priority
      99999
    end

    def no_automod_config?
      true
    end

    def static_mod_action_check?(rabbit_message)
      ACTION == rabbit_message[:reddit][:action] && DETAIL == rabbit_message[:reddit][:details]
    end

    def mod_action_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_mod_action(custom_action)
      super(custom_action)
      rules_config.fetch_config!
    end
  end
end
