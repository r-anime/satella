module Rules
  class SourceMaterialCornerRule < BaseRule
    FLAIR_NAME_REGEX = /Episode/i # not present in original rule
    DATE_GATE = Time.parse(ENV["DATE_GATE"]) # temp

    def name
      "Source Material Corner Rule"
    end

    def on_upsert
      @authors_regex = /#{Array(config["author"]["name"]).map { |a| Regexp.escape(a) }.join("|")}/i
      @body_regex = /#{Regexp.escape(config["body"])}/i if config["body"]

      @comment_text = config["comment"]
      @comment_sticky = !!config["comment_stickied"]
    end

    def static_post_check?(rabbit_message)
      DATE_GATE <= Time.at(rabbit_message[:reddit][:created_utc]) &&
        FLAIR_NAME_REGEX.match?(rabbit_message[:reddit][:link_flair_text]) &&
        @authors_regex.match?(rabbit_message[:reddit][:author][:name]) &&
        @body_regex.match?(rabbit_message[:reddit][:selftext])
    end

    def post_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_post(custom_action)
      super(custom_action)
      reddit.mod_comment(custom_action.rabbit_message[:reddit][:name], @comment_text, sticky: @comment_sticky)
    end
  end
end
