module Rules
  class MediaDurationRule < BaseRule
    def name
      "Media Duration Rule"
    end

    def on_upsert
      @flair_configs = parse_multi_flair_config do |flair_config|
        flair_config[:duration_range] = (flair_config[:min_duration]..flair_config[:max_duration])
        flair_config[:removal_text] = toolbox_service.parse_toolbox_removal_reason(
          module_name: name,
          exact_title: flair_config[:toolbox_removal_title],
          bold_substring_identifier: flair_config[:toolbox_bold_substring_identifier]
        )
        flair_config
      end
    end

    def static_post_check?(rabbit_message)
      @flair_configs[rabbit_message[:reddit][:link_flair_text]] && (
        rabbit_message[:reddit][:is_video] || rabbit_message.dig(:reddit, :media, :type) == 'youtube.com'
      )
    end

    def post_check(rabbit_message)
      flair_config = @flair_configs[rabbit_message[:reddit][:link_flair_text]]
      duration = rabbit_message.dig(:reddit, :media, :reddit_video, :duration) || fetch_duration!(rabbit_message[:reddit][:media])

      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) if flair_config[:duration_range].include?(duration)

      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {removal_text: flair_config[:removal_text]})
    end

    def execute_post(custom_action)
      super(custom_action)
      reddit.remove_with_reason(custom_action.rabbit_message[:reddit][:name], custom_action.args[:removal_text])
    end

    private

    def fetch_duration!(media)
      id = media[:oembed][:thumbnail_url].split('/vi/').last.split('/').first
      youtube_service.fetch_video_duration(id)
    end
  end
end
