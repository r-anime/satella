module Rules
  class SourceCornerCreationRuleIsekaiQuartet < SourceCornerCreationRule
    def name
      "Source Corner Creation Rule (Isekai Quartet)"
    end

    def on_upsert
      super
      @title_regex = /#{Regexp.escape(config["title"])}/i
    end

    def static_post_check?(rabbit_message)
      @authors_regex.match?(rabbit_message[:reddit][:author][:name]) &&
        @title_regex.match?(rabbit_message[:reddit][:title])
    end
  end
end
