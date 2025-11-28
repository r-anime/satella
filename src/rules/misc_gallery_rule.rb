module Rules
  class MiscGalleryRule < BaseRule
    def name
      "Misc Gallery Rule"
    end

    def on_upsert
      @flair_ids = Array(config["flair_template_id"]).to_set
      @number_of_required_images = config["poll_option_count"]

      @comment_text = config["comment"]
    end

    def static_post_check?(rabbit_message)
      rabbit_message[:reddit][:is_gallery] && # check that this is even a gallery in the first place
        @flair_ids.include?(rabbit_message[:reddit][:link_flair_template_id]) &&
        rabbit_message[:reddit][:media_metadata].size < @number_of_required_images
    end

    def post_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_post(custom_action)
      super(custom_action)
      removal_text = @comment_text.sub("{{number_of_required_images}}", @number_of_required_images.to_s)
      reddit.remove_with_reason(custom_action.rabbit_message[:reddit][:name], removal_text)
    end
  end
end
