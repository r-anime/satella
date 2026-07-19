module Rules
  class MediaResolutionRule < BaseRule
    def name
      "Media Resolution Rule"
    end

    def on_upsert
      @flair_configs = parse_multi_flair_config
    end

    def static_post_check?(rabbit_message)
      @flair_configs[rabbit_message[:reddit][:link_flair_text]] && (
        rabbit_message[:reddit][:is_video] || rabbit_message.dig(:reddit, :media, :type) == 'youtube.com'
      )
    end

    def post_check(rabbit_message)
      flair_config = @flair_configs[rabbit_message[:reddit][:link_flair_text]]

      if rabbit_message.dig(:reddit, :media, :reddit_video)
        handle_native_reddit(rabbit_message, flair_config)
      else
        handle_youtube(rabbit_message, flair_config)
      end
    end

    def execute_post(custom_action)
      super(custom_action)
      reddit.report(custom_action.rabbit_message[:reddit][:name], custom_action.args[:report_reason])
    end

    private

    def handle_native_reddit(rabbit_message, flair_config)
      width = rabbit_message[:reddit][:media][:reddit_video][:width]
      height = rabbit_message[:reddit][:media][:reddit_video][:height]

      if width > flair_config[:min_width] && height > flair_config[:min_height]
        return RuleResult::NoAction.new(rule_module: self, rabbit_message:)
      end

      resolution = "#{width}x#{height}"
      report_reason = placeholder_service.replace_placeholders(flair_config[:report_reason], customs: {resolution:})
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {report_reason:})
    end

    def handle_youtube(rabbit_message, flair_config)
      id = youtube_service.extract_id(rabbit_message[:reddit][:media])
      definition = youtube_service.fetch_video_resolution(id).upcase

      report_reason = placeholder_service.replace_placeholders(flair_config[:report_reason], customs: {resolution: definition})
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {report_reason:})
    end
  end
end
