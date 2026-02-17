require 'dotenv/load'

require_relative './src/logger'
require_relative './src/services/reddit_service'

def main(old_username, new_username)
  reddit = RedditService.new(
    user_agent: ENV['REDDIT_USER_AGENT_RUBY'],
    client_id: ENV['REDDIT_CLIENT_ID'],
    secret: ENV['REDDIT_SECRET'],
    username: ENV['REDDIT_USERNAME'],
    password: ENV['REDDIT_USER_PASSWORD']
  )

  $logger.info { "Transferring mod notes from #{old_username} -> #{new_username}" }

  old_notes = reddit.fetch_mod_notes(old_username, subreddit: "anime", filter: 'NOTE')

  to_transfer = old_notes[:mod_notes].map do |old_note|
    data = old_note[:user_note_data]
    time = Time.at(old_note[:created_at]).utc
    original_noter = old_note[:operator]
    message = "#{time} by u/#{original_noter}: #{data[:note]}"
    {label: data[:label], reddit_id: data[:reddit_id], message: message, }
  end.reverse

  to_transfer.each do |new_note|
    $logger.info { new_note }
  end

  $logger.info { "Transfer mod notes from #{old_username} -> #{new_username}? (y/n): " }
  answer = STDIN.gets&.chomp&.downcase

  if answer != "y"
    $logger.info { "Confirmation denied for mod note transfer from #{old_username} -> #{new_username}" }
    exit
  end

  $logger.info { "Confirmation received. Transferring mod notes from #{old_username} -> #{new_username}" }

  to_transfer.each do |new_note|
    $logger.info { "Transferring: #{new_note}" }
    reddit.create_mod_note(new_username, new_note[:label], new_note[:message], subreddit: "anime", reddit_id: new_note[:reddit_id])
    sleep 10
  end

  $logger.info { "Finished transferring mod notes from #{old_username} -> #{new_username}" }
end

main *ARGV
