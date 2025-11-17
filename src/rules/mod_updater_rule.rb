module Rules
  class ModUpdaterRule < BaseRule
    ACTIONS = Set.new(['removemoderator', 'acceptmoderatorinvite'])

    def name
      "Mod Updater Rule"
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
      ACTIONS.include?(rabbit_message[:reddit][:action])
    end

    def mod_action_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_mod_action(custom_action)
      super(custom_action)
      rules_config.fetch_mods!
    end
  end
end
