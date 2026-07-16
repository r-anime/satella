require 'google/apis/youtube_v3'
require 'iso8601'

class YouTubeService
  attr_accessor :client

  def initialize(api_token)
    @client = Google::Apis::YoutubeV3::YouTubeService.new
    @client.key = api_token
  end

  def fetch_video_duration(id)
    $logger.debug { "Fetching YouTube duration for #{id}" }
    response = @client.list_videos('contentDetails', id:)
    ISO8601::Duration.new(response.items.first.content_details.duration).to_seconds.to_i
  end
end
