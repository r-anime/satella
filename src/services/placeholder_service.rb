class PlaceholderService
  def replace_template_placeholders(template_str)
    template_str.gsub("{{subreddit}}", ENV["SUBREDDIT_NAME_TO_ACT_ON"])
  end

  # TODO add more placeholders
  # TODO author
  # TODO author_flair_text
  # TODO author_flair_css_class
  # TODO author_flair_template_id
  # TODO body
  # TODO permalink
  # TODO title
  # TODO url
  # TODO match (at first just support single match)
  # TODO media_author
  # TODO media_author_url
  # TODO media_title
  # TODO media_description

  # TODO replace multiple placeholders more efficiently
  # TODO allow custom placeholders via hash
  def replace_placeholders(str, fullname: nil)
    str = replace_kind(str, fullname) if fullname
    str
  end

  private

  def replace_kind(str, fullname)
    kind =
      if fullname.start_with?("t1_")
        "comment"
      elsif fullname.start_with?("t3_")
        "submission"
      else
        "???"
      end
    str.gsub("{{kind}}", kind)
  end
end
