module Rules
  class SourceMaterialCornerIsekaiQuartetRule < SourceMaterialCornerRule
    FLAIR_NAME_REGEX = /Episode/i

    def name
      "Source Material Corner Rule (Isekai Quartet)"
    end

    def on_upsert
      super
      @title_regex = /#{Regexp.escape(config["title"])}/i
    end


    def static_post_check?(rabbit_message)
      FLAIR_NAME_REGEX.match?(rabbit_message[:reddit][:link_flair_text]) &&
        @authors_regex.match?(rabbit_message[:reddit][:author][:name]) &&
        @title_regex.match?(rabbit_message[:reddit][:title])
    end
  end
end
