module Rules
  class QuestionOfTheDayRule < BaseRule
    def self.name
      "Question of the Day Rule"
    end

    def on_upsert
      @authors_regex = /#{Array(config["author"]["name"]).map { |a| Regexp.escape(a) }.join("|")}/i if config.dig("author", "name")
      @flair_ids = Array(config["flair_template_id"]).to_set
      @title_prefix = config["title (starts-with)"]&.downcase

      @comment_text = config["comment"]
      @comment_sticky = !!config["comment_stickied"]
    end

    def static_post_check?(rabbit_message)
      (!@authors_regex || @authors_regex.match?(rabbit_message[:reddit][:author][:name])) &&
        (!@title_prefix || rabbit_message[:reddit][:title].downcase.strip.start_with?(@title_prefix)) &&
        @flair_ids.include?(rabbit_message[:reddit][:link_flair_template_id])
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
