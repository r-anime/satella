module Rules
  class ToolboxUpdaterRule < BaseRule
    ACTION = 'wikirevise'
    DETAIL = 'Page toolbox edited'

    def name
      "Toolbox Updater Rule"
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
      toolbox_service.fetch_toolbox!
      rules_config.fetch_config! # upsert rule modules in case they depend on toolbox as part of their upsert config
    end
  end
end
