require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'],
  port: ENV['DB_PORT'],
  database: ENV['DB_NAME'],
  username: ENV['DB_USER'],
  password: ENV['DB_PASSWORD']
)

Dir[File.join(__dir__, 'models', '**', '*.rb')].each do |file|
  require_relative file
end
