require 'time'
require "active_support/core_ext/numeric/time"

module Rules
  class NewCommentOnOldPostRule < BaseRule
    def name
      "New Comment On Old Post Rule"
    end

    def on_upsert
      @normal_age_threshold = config["body"]["normal_age_threshold"].days
      @removed_age_threshold = config["body"]["removed_age_threshold"].days
      @min_age_threshold = [@normal_age_threshold, @removed_age_threshold].min

      @report_template = config["action_reason"]
    end

    def static_comment_check?(rabbit_message)
      true # no static component, have to check everything
    end

    def comment_check(rabbit_message)
      post = Post.select(:created_time, :removed).find(rabbit_message[:db][:post_id])
      comment_created_time = Time.at(rabbit_message[:reddit][:created_utc]).utc
      age = (comment_created_time - post.created_time)

      if (post.removed && age > @removed_age_threshold) || (age > @normal_age_threshold)
        return RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {post: post, age: age})
      end
      RuleResult::NoAction.new(rule_module: self, rabbit_message:)
    end

    def execute_comment(custom_action)
      super(custom_action)
      custom_action.args => {post:, age:}
      age_str = "#{(age / 1.days).round(2).to_s} day"
      report_message = @report_template.gsub('{{age}}', age_str).gsub('{{is_removed}}', post.removed ? 'removed ' : '')
      reddit.report(custom_action.rabbit_message[:reddit][:name], report_message)
    end
  end
end
