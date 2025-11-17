module Rules
  class SourceCornerCreationRuleIsekaiQuartet < SourceCornerCreationRule
    FLAIR_NAME_REGEX = /Episode/i # not present in original rule
    DATE_GATE = Time.parse(ENV["DATE_GATE"]) # temp

    def name
      "Source Corner Creation Rule (Isekai Quartet)"
    end

    def on_upsert
      super
      @title_regex = /#{Regexp.escape(config["title"])}/i
    end

    def static_post_check?(rabbit_message)
      DATE_GATE <= Time.at(rabbit_message[:reddit][:created_utc]) &&
        FLAIR_NAME_REGEX.match?(rabbit_message[:reddit][:link_flair_text]) &&
        @authors_regex.match?(rabbit_message[:reddit][:author][:name]) &&
        @title_regex.match?(rabbit_message[:reddit][:title])
    end
  end
end
