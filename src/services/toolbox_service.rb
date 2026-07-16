require 'nokogiri'
require 'uri'

class ToolboxService
  attr_reader :reddit, :discord
  attr_accessor :config

  def initialize(reddit:, discord:)
    @reddit = reddit
    @discord = discord
    @config = {}
  end

  def fetch_toolbox!
    config = reddit.fetch_toolbox(ENV['SUBREDDIT_NAME_TO_ACT_ON'])
    $logger.debug { "Fetched toolbox config" }

    @config = decode_url_encoded(config)
    $logger.info { "Successfully updated toolbox config" }
  end

  # @helper true
  # A helper method that find the toolbox removal reason and optionally bold a selected identifier.
  # Other selects will use the preselected value
  # @return the markdown to remove with
  def parse_toolbox_removal_reason(module_name:, exact_title:, bold_substring_identifier: nil)
    raw_html = config[:removalReasons][:reasons].find do |removal_reason|
      removal_reason[:title] == exact_title
    end&.dig(:text)

    if raw_html.nil?
      discord.add_urgent_message!(
        "Rule Module \"#{module_name}\" could not find the toolbox removal reason \"#{exact_title}\". Non informative removal message will be used instead."
      )
      return "Removal reason text not found"
    end

    html = Nokogiri::HTML::DocumentFragment.parse(raw_html)

    html.css("select").each do |select|
      options = select.css("option")
      selected = options.find { |option| option["selected"] }
      next_option = options[options.index(selected) + 1]

      select.replace(
        if bold_substring_identifier && next_option["value"].include?(bold_substring_identifier)
          next_option["value"]
        else
          selected["value"]
        end
      )
    end

    html.text
  end

  private

  def decode_url_encoded(obj)
    case obj
      when String
        # Needed to handle non standard unicode encoding from Javascript. Replaces the unicode encoding with the actual char
        str = obj.gsub(/%u([0-9A-Fa-f]{4,6})/) do
          [$1.to_i(16)].pack("U")
        end
        URI.decode_uri_component(str)
      when Hash
        obj.transform_values { |value| decode_url_encoded(value) }
      when Array
        obj.map { |value| decode_url_encoded(value) }
      else
        obj
    end
  end
end
