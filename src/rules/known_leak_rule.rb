module Rules
  class KnownLeakRule < BaseRule
    def self.name
      "Known Leak Rule"
    end

    def on_upsert
      @title_regex = /#{config["title"]}/i
      @date_time = Time.parse(config['body']['official_datetime']).utc

      @toolbox_removal_reason = toolbox_service.parse_toolbox_removal_reason(
        module_name: name,
        exact_title: config['body']['toolbox_removal_title'],
        bold_substring_identifier: config['body']['toolbox_bold_substring_identifier']
      )
      @comment_text = @toolbox_removal_reason + "\n\n " +  @placeholder_service.replace_template_placeholders(config["comment"])
    end

    def static_post_check?(rabbit_message)
      @title_regex.match?(rabbit_message[:reddit][:title]) && Time.at(rabbit_message[:reddit][:created_utc]) < @date_time
    end

    def post_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_post(custom_action)
      super(custom_action)
      reddit.remove_with_reason(custom_action.rabbit_message[:reddit][:name], @comment_text)
    end
  end
end
