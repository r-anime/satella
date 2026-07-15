require 'time'
require "active_support/core_ext/numeric/time"

module Rules
  class FlairFrequencyRule < BaseRule
    DISCORD_IGNORE_COLOR = 0x808080
    DISCORD_UNIGNORE_COLOR = 0xFFFFFF
    SECONDS_IN_A_DAY = 60 * 60 * 24

    def name
      "Flair Frequency Rule"
    end

    def on_upsert
      @flair_configs = @flair_configs = parse_multi_flair_config
      @removal_comment_template = @placeholder_service.replace_template_placeholders(config["comment"])
      @ignore_command = config["body"]["exemption_comment_commands"]["ignore_command"].downcase
      @unignore_command = config["body"]["exemption_comment_commands"]["unignore_command"].downcase
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
        .and(
          Post
            .left_joins(:flair_frequency_exemption)
            .where(flair_frequency_exemptions: {id: nil}
            ).or(
            Post.where(flair_frequency_exemptions: {is_exempt: false}
            )
          ))
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

    def static_comment_check?(rabbit_message)
      comment_body = rabbit_message[:reddit][:body].strip.downcase
      rules_config.mods.include?(rabbit_message[:reddit][:author][:name]) &&
        (comment_body == @ignore_command || comment_body == @unignore_command)
    end

    def comment_check(rabbit_message)
      post = Post.find(rabbit_message[:db][:post_id])
      flair_config = @flair_configs[post.flair_text]
      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) unless flair_config

      comment_body = rabbit_message[:reddit][:body].strip.downcase
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {post:, is_exempt: comment_body == @ignore_command})
    end

    def execute_comment(custom_action)
      super(custom_action)
      post = custom_action.args[:post]
      is_exempt = custom_action.args[:is_exempt]

      FlairFrequencyExemption.upsert({post_id: post.id, is_exempt:}, unique_by: :post_id)
      discord.post_mod_log_webhook(
        [
          {
            title: post.title.truncate(256),
            url: "https://redd.it/#{post.id36}",
            author: {name: "/u/#{post.author}"},
            description: "/u/#{custom_action.rabbit_message[:reddit][:author][:name]} #{is_exempt ? "ignored" : "unignored"} this post for the flair frequency rule module",
            timestamp: Time.at(custom_action.rabbit_message[:reddit][:created_utc]).iso8601,
            color: is_exempt ? DISCORD_IGNORE_COLOR : DISCORD_UNIGNORE_COLOR,
          }
        ]
      )
      reddit.remove(custom_action.rabbit_message[:reddit][:name])
    end

    private

    def to_human_duration(duration)
      duration = duration.to_i
      days = duration / SECONDS_IN_A_DAY
      duration = duration % SECONDS_IN_A_DAY
      hours = (duration / 3600.0).round(2)
      str = ""
      str += "#{days} day#{days > 1 ? 's' : ''} and " if days > 0
      str += "#{hours} hours"
      str
    end
  end
end
