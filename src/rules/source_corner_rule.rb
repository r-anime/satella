require 'time'

module Rules
  class SourceMaterialRule < BaseRule
    DATE_GATE = Time.parse(ENV["DATE_GATE"]) # temp

    def name
      "Source Corner Rule"
    end

    def on_upsert
      @flair_ids = Array(config["parent_submission"]["flair_template_id"]).to_set
      @authors_regex = /#{Array(config["author"]["name"]).map { |a| Regexp.escape(a) }.join("|")}/i
      @body_regex = /(#{Array(config["body (includes, regex)"]).join("|")})/i if config["body (includes, regex)"]

      @report_template = config["action_reason"]
    end

    def static_comment_check?(rabbit_message)
      # ignore bot messages
      ENV["REDDIT_USERNAME"] != rabbit_message[:reddit][:author][:name] &&
        # ignore old top level comments (they're already handled)
        (DATE_GATE <= Time.at(rabbit_message[:reddit][:created_utc]) || rabbit_message[:reddit][:parent_id].start_with?('t1_')) &&
        @authors_regex.match?(rabbit_message[:reddit][:link_author])
    end

    def comment_check(rabbit_message)
      match_data = @body_regex.match(rabbit_message[:reddit][:body])
      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) unless match_data

      is_right_flair = Post.exists?(id: rabbit_message[:db][:post_id], flair_id: @flair_ids)
      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) unless is_right_flair

      in_source_corner = Comment.is_in_source_corner?(rabbit_message[:reddit][:id])
      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) if in_source_corner

      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {match_data: match_data})
    end

    def execute_comment(custom_action)
      super(custom_action)
      reddit.report(
        custom_action.rabbit_message[:reddit][:name],
        @report_template.sub('{{match}}', custom_action.args[:match_data][1])
      )
    end
  end
end
