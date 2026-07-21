require 'time'
require "active_support/core_ext/numeric/time"

module Rules
  class TestRule < BaseRule
    def self.name
      "Test 1 Rule"
    end

    def on_upsert
      @trigger = config["body"]["trigger"]
    end

    def static_comment_check?(rabbit_message)
      rabbit_message[:reddit][:author][:name] != 'AnimeMod' && rabbit_message[:reddit][:body].include?(@trigger)
    end

    def comment_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {trigger: @trigger})
    end

    def execute_comment(custom_action)
      super(custom_action)
      reddit.reply_comment(custom_action.rabbit_message[:reddit][:name], "Triggered Test rule 1 on \"#{@trigger}\"")
    end
  end
end
