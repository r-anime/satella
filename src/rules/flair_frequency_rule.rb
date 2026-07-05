require 'time'
require "active_support/core_ext/numeric/time"

module Rules
  class FlairFrequencyRule < BaseRule
    def name
      "Flair Frequency Rule"
    end

    def on_upsert
      @flair_configs = config["body"].flat_map do |flair_config|
        Array(flair_config["flairs"]).map do |flair|
          [flair, flair_config.symbolize_keys.merge(flairs: Array(flair_config["flairs"]))]
        end
      end.map do |(flair, c)|
        [flair, c.merge(human_flairs: c[:flairs].join("/"))]
      end.to_h
      @removal_comment_template = @placeholder_service.replace_template_placeholders(config["comment"])
    end

    def static_post_check?(rabbit_message)
      @flair_configs.include?(rabbit_message[:reddit][:link_flair_text])
    end

    def post_check(rabbit_message)
      flair_config = @flair_configs[rabbit_message[:reddit][:link_flair_text]]
      post_time = Time.at(rabbit_message[:reddit][:created_utc]).utc

      prior_posts = Post
        .left_outer_joins(:flair_frequency_exemption)
        .where(
          flair_text: flair_config[:flairs],
          created_time: (post_time - flair_config[:period].days)...post_time,
          removed: false
        )
        .where("lower(author) = ?", rabbit_message[:reddit][:author][:name].downcase)
        .where.not(id36: rabbit_message[:reddit][:id])
        .where(
          flair_frequency_exemptions: {id: nil}
        ).or(Post
               .left_joins(:flair_frequency_exemption)
               .where(flair_frequency_exemptions: {is_exempt: false})
      )
        .order(created_time: :asc)
        .load

      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) if prior_posts.size < flair_config[:allowed]

      allowed_timestamp = prior_posts[0].created_time + flair_config[:period].days + 15.minutes # 15 minute extra buffer
      duration_left = to_human_duration(allowed_timestamp - Time.now)
      previous_posts = prior_posts.each_with_index.map do |post, index|
        "#{index + 1}. #{post.created_time.httpdate}: [#{post.flair_text}] [#{post.title}](https://redd.it/#{post.id36})"
      end.join("\n")
      removal_text = placeholder_service.replace_placeholders(@removal_comment_template, customs: {
        allowed: flair_config[:allowed],
        human_flairs: flair_config[:human_flairs],
        plural: flair_config[:allowed] > 1 ? 's' : '',
        period: flair_config[:period],
        duration_left:,
        previous_posts:,
      })

      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {removal_text:})
    end

    def execute_post(custom_action)
      super(custom_action)
      reddit.remove_with_reason(custom_action.rabbit_message[:reddit][:name], custom_action.args[:removal_text])
    end

    # TODO comments, handle exemptions handling

    private

    def to_human_duration(duration)
      duration = duration.to_i
      days = duration / 84600
      duration = duration % 86400
      hours = (duration / 3600.0).round(2)
      str = ""
      str += "#{days} day#{days > 1 ? 's' : ''} and " if days > 0
      str += "#{hours} hours"
      str
    end
  end
end
