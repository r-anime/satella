require_relative '../logger'
require 'time'

module Rules
  # TODO consider making more generic, probably need StandardRule for that though
  # TODO generate tests, implementation should be done at a basic level
  class EpisodeDiscussionTempCommentSortRule < BaseRule
    def name
      "Episode Discussion Temp Comment Sort Rule"
    end

    def on_upsert
      @authors_regex = /#{Array(config["author"]["name"]).map { |a| Regexp.escape(a) }.join("|")}/i
      start_time = Time.parse(config["body"]["start_date"]) if config["body"]["start_date"]
      expire_time = Time.parse(config["body"]["expire_date"]) if config["body"]["expire_date"]
      @time_range = (start_time..expire_time)
      @temp_sort = config["body"]["sort"]
      @duration = config["body"]["duration"].hours
      @returning_sort = config["body"]["returning_sort"]

      # Hash.new{|h,k| h[k] = {reset_time: nil, reset: false}} # TODO remove with proper delay
      @cache_reset_processed = Hash.new(false) # TODO remove with proper delay
      @cache_reset_time = {} # TODO remove with proper delay

      puts "start_time: #{start_time}"
      puts "expire_time: #{expire_time}"
      puts "time_range: #{@time_range}"
      puts "@temp_sort: #{@temp_sort}"
      puts "@duration: #{@duration}"
      puts "@returning_sort: #{@returning_sort}"
    end

    def static_post_check?(rabbit_message)
      # DEBUG tested the range timing with nulls, works as intended
      !@cache_reset_processed[rabbit_message[:db][:id]] &&
        @time_range.include?(Time.at(rabbit_message[:reddit][:created_utc]).utc) &&
        @authors_regex.match?(rabbit_message[:reddit][:author][:name])
    end

    def post_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_post(custom_action)
      super(custom_action)
      post_id = custom_action.rabbit_message[:db][:id]
      puts "post_id: #{post_id}"
      @cache_reset_processed[post_id] = false
      puts "Time: #{Time.at(custom_action.rabbit_message[:reddit][:created_utc]).utc}"
      @cache_reset_time[post_id] = Time.at(custom_action.rabbit_message[:reddit][:created_utc]).utc + @duration
      puts "@cache_reset_time[#{post_id}]: #{@cache_reset_time[post_id]}"
      reddit.set_default_comment_sort(custom_action.rabbit_message[:reddit][:name], @temp_sort)
    end

    # TODO remove entire comment processing and replace with proper delay
    def static_comment_check?(rabbit_message)
      post_id = rabbit_message[:db][:post_id]
      puts "@cache_reset_processed[#{post_id}]: #{@cache_reset_processed[post_id]}"
      puts "@cache_reset_time[#{post_id}]: #{@cache_reset_time[post_id]}"
      # return false if @cache_reset_processed[post_id]
      # puts "match_author: #{@authors_regex.match?(rabbit_message[:reddit][:link_author])}"
      # @authors_regex.match?(rabbit_message[:reddit][:link_author])
      !@cache_reset_processed[post_id] && @authors_regex.match?(rabbit_message[:reddit][:link_author])
    end

    def comment_check(rabbit_message)
      post_id = rabbit_message[:db][:post_id]
      puts "post_id: #{post_id}"
      comment_time = Time.at(rabbit_message[:reddit][:created_utc]).utc
      puts "comment_time: #{comment_time}"

      if !@cache_reset_time[post_id]
        post_created_time = Post.find(post_id)&.created_time # TODO optimize sql and error handling

        if post_created_time.nil?
          $logger.info "[#{name}] Could not find post created_time for id: #{post_id} in DB. Rejecting."
          return RuleResult::NoAction.new(rule_module: self, rabbit_message:)
        end

        if !@time_range.include?(post_created_time)
          # not part of the trial
          $logger.info "Post id: #{post_id.to_s(36)} posted at #{post_created_time} is not part of the trial period: #{@time_range}"
          @cache_reset_processed[post_id] = true # optimization to never process this post again
          return RuleResult::NoAction.new(rule_module: self, rabbit_message:)
        end

        @cache_reset_time[post_id] = post_created_time + @duration
        @cache_reset_processed[post_id] = comment_time >= @cache_reset_time[post_id]
        puts "@cache_reset_time[#{post_id}] (after set cache): #{@cache_reset_time[post_id]}"
      end

      puts "comment_time check: #{comment_time >= @cache_reset_time[post_id]}"
      return RuleResult::NoAction.new(rule_module: self, rabbit_message:) if comment_time < @cache_reset_time[post_id]

      # if doesn't match author, bail out false
      # if in cache, rely on that
      # if not in cache, then lookup post created_time in db, and populate cache, set reset time, and if after comment time

      RuleResult::CustomAction.new(rule_module: self, rabbit_message:, args: {post_id:, })
    end

    def execute_comment(custom_action)
      super(custom_action)
      post_id = custom_action.rabbit_message[:db][:post_id]
      puts "reset post_id: #{post_id}"
      @cache_reset_processed[post_id] = true
      puts "reset @cache_reset_processed[#{post_id}]: #{@cache_reset_processed[post_id]}"
      reddit.set_default_comment_sort("t3_#{post_id.to_s(36)}", @returning_sort)
    end
  end
end
