module Rules
  class ThreadRotatorRule < BaseRule
    def self.name
      "Thread Rotator Rule"
    end

    def on_upsert
      if config.dig("author", "name")
        @authors = Array(config["author"]["name"]).map(&:downcase)
        @authors_regex = /#{@authors.map { |a| Regexp.escape(a) }.join("|")}/i
      else
        @authors = nil
        @authors_regex = nil
      end
      @flair_ids = Array(config["flair_template_id"]).to_set
      @title_prefix = config["title (starts-with)"]&.downcase

      @comment_text_template = placeholder_service.replace_template_placeholders(config["comment"])
      @comment_sticky = !!config["comment_stickied"]

      @widget_topbar_name = config["body"]["widget_topbar_name"]
      @widget_topbar_subname = config["body"]["widget_topbar_subname"]
      @widget_sidebar_name = config["body"]["widget_sidebar_name"]
      @widget_sidebar_link_text = config["body"]["widget_sidebar_link_text"]

      # sync_prod_widgets_to_staging
    end

    def static_post_check?(rabbit_message)
      (!@authors_regex || @authors_regex.match?(rabbit_message[:reddit][:author][:name])) &&
        (!@title_prefix || rabbit_message[:reddit][:title].downcase.strip.start_with?(@title_prefix)) &&
        @flair_ids.include?(rabbit_message[:reddit][:link_flair_template_id])
    end

    def post_check(rabbit_message)
      RuleResult::CustomAction.new(rule_module: self, rabbit_message:)
    end

    def execute_post(custom_action)
      super(custom_action)
      previous_post = find_previous_post(rabbit_message: custom_action.rabbit_message)

      link_posts(rabbit_message: custom_action.rabbit_message, previous_post:)
      update_sidebars(rabbit_message: custom_action.rabbit_message)
    end

    private

    def find_previous_post(rabbit_message:)
      new_thread_created_time = Time.at(rabbit_message[:reddit][:created_utc])

      post_query = Post.where(created_time: ...new_thread_created_time, flair_id: @flair_ids, removed: false)
      post_query = post_query.where("lower(author) = ?", @authors) if @authors
      post_query = post_query.where("title ILIKE ?", @title_prefix + "%") if @title_prefix

      post_query.order(created_time: :desc).take
    end

    def link_posts(rabbit_message:, previous_post:)
      comment_text = placeholder_service.replace_placeholders(@comment_text_template, customs: {
        new_link: rabbit_message[:reddit][:url]
      })
      reddit.mod_comment("t3_#{previous_post.id36}", comment_text, sticky: @comment_sticky, reply_notifications: false)

      previous_post_content = previous_post
        .body
        .gsub(/\[Next Thread »\]\(.*?\)/, "[Next Thread »](#{rabbit_message[:reddit][:url]})")
        .gsub(/\[(.*?)\]\(https:\/\/preview\.redd\.it\/(\w+)\..*?\)/, '![img](\2 "\1")') # broken. try rich text json?
      @reddit.edit_post(previous_post.id36, previous_post_content)
      $logger.info { "#{self.class.name}: Updated old #{@widget_sidebar_link_text} (#{previous_post.id36})" }

      current_post_content = rabbit_message[:reddit][:selftext]
        .gsub(/\[« Previous Thread\]\(.*?\)/, "[« Previous Thread](https://www.reddit.com/r/#{ENV["SUBREDDIT_NAME_TO_ACT_ON"]}/comments/#{previous_post.id36})")
        .gsub(/\[(.*?)\]\(https:\/\/preview\.redd\.it\/(\w+)\..*?\)/, '![img](\2 "\1")') # broken
      @reddit.edit_post(rabbit_message[:reddit][:id], current_post_content)
      $logger.info { "#{self.class.name}: Updated new #{@widget_sidebar_link_text} (#{previous_post.id36})" }
    end

    def update_sidebars(rabbit_message:)
      update_old_sidebars(rabbit_message:)
      update_shit_sidebars(rabbit_message:)
    end

    def update_old_sidebars(rabbit_message:)
      sidebar = @reddit.fetch_wiki_page("config/sidebar")
      previous_revision = sidebar[:data][:revision_id]

      new_content = sidebar[:data][:content_md].gsub(/(\[#{@widget_sidebar_link_text}\]\()(.*?)(\))/, "\\1#{rabbit_message[:reddit][:url]}\\3")

      if sidebar[:data][:content_md] == new_content
        $logger.info { "#{self.class.name}: Old reddit sidebar unchanged. Not updating." }
        return
      end

      @reddit.edit_wiki_page("config/sidebar", new_content, previous_revision:, reason: "Updated Megathread links for #{@widget_sidebar_link_text}")
    end

    def update_shit_sidebars(rabbit_message:)
      widgets = @reddit.fetch_widgets

      topbar_widget_id = widgets[:layout][:topbar][:order].first
      topbar_widget = widgets[:items][topbar_widget_id.to_sym]

      topbar_widget[:data].find { |widget| widget[:text] == @widget_topbar_name }[:children]
                          .find { |widget| widget[:text] == @widget_topbar_subname }[:url] =
        rabbit_message[:reddit][:url]

      sidebar_widget = widgets[:items].values.find do |widget|
        widget&.[](:shortName) == @widget_sidebar_name
      end
      sidebar_widget[:text].gsub!(/(\[#{@widget_sidebar_link_text}\]\()(.*?)(\))/, "\\1#{rabbit_message[:reddit][:url]}\\3")

      # TODO optimization to not update if not changed
      @reddit.update_widget(topbar_widget[:id], topbar_widget)
      @reddit.update_widget(sidebar_widget[:id], sidebar_widget)
      $logger.info { "#{self.class.name}: Updated the shit reddit sidebars" }
    end

    # TODO attempt to check if it already exists beforehand before deleting and remaking
    # Note, this doesn't carry over image widgets and will clear out the staging widgets
    def sync_prod_widgets_to_staging
      $logger.info { "#{self.class.name}: SYNCING PROD WIDGETS TO STAGING" }
      staging_widgets = @reddit.fetch_widgets(subreddit: "animestaging")
      prod_widgets = @reddit.fetch_widgets(subreddit: "anime")

      prod_to_stage_id_map = {}
      prod_widgets[:items].keys.each do |prod_widget_id|
        next unless prod_widget_id.to_s.include?("-")
        prefix = prod_widget_id.to_s.split("-", 2).first
        prod_to_stage_id_map[prod_widget_id.to_s] = staging_widgets[:items].keys.find do |staging_widget_id|
          staging_widget_id.to_s.start_with?(prefix)
        end
      end
      $logger.debug { "#{self.class.name}: prod_to_stage_id_map: #{prod_to_stage_id_map}" }

      staging_widgets[:items].each do |staging_widget_id, staging_widget_data|
        next if staging_widget_id.to_s.include?("-")
        $logger.info { "#{self.class.name}: deleting staging widget id: #{staging_widget_id}" }
        @reddit.delete_widget(staging_widget_id, subreddit: "animestaging")
      end

      (prod_widgets[:layout][:topbar][:order] + prod_widgets[:layout][:sidebar][:order])
        .each do |prod_widget_id|
        next if prod_widget_id.include?("-")
        prod_widget_data = prod_widgets[:items][prod_widget_id.to_sym]
        next if prod_widget_data[:kind] == "image" # images give bad url error
        $logger.info { "#{self.class.name}: adding prod widget id: #{prod_widget_id}" }
        resp = @reddit.create_widget(prod_widget_data, subreddit: "animestaging")
        prod_to_stage_id_map[prod_widget_id] = resp[:id]
      end

      widget_order = prod_widgets[:layout][:sidebar][:order]
        .map { |prod_widget_id| prod_to_stage_id_map[prod_widget_id] }
        .compact
      @reddit.update_widget_order("sidebar", widget_order, subreddit: "animestaging")
    end
  end
end
