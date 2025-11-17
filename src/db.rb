require 'active_record'
require 'active_support/logger'
require "active_support/broadcast_logger"
require 'fileutils'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'],
  port: ENV['DB_PORT'],
  database: ENV['DB_NAME'],
  username: ENV['DB_USER'],
  password: ENV['DB_PASSWORD']
)

console_logger = Logger.new(STDOUT)

FileUtils.mkdir_p(File.dirname(ENV["LOG_FILE_SATELLA_DB_PATH"]))
file_logger = Logger.new(
  ENV["LOG_FILE_SATELLA_DB_PATH"],
  ENV.fetch('LOG_FILE_NUMBER_FILES', "3").to_i,
  ENV.fetch('LOG_FILE_MAX_MEBIBYTES', "1").to_i * 1024 * 1024,
  level: Logger.const_get(ENV.fetch('LOG_LEVEL_FILE', 'INFO'))
)

ActiveRecord::Base.logger = ActiveSupport::BroadcastLogger.new(console_logger, file_logger)
ActiveRecord::Base.logger.level = Logger.const_get(ENV.fetch('LOG_LEVEL_DB', 'INFO'))

Dir[File.join(__dir__, 'models', '**', '*.rb')].each do |file|
  require_relative file
end

begin
  ActiveRecord::Base.connection.execute("SELECT 1")
  $logger.info "Successfully connected to postgres"
rescue => e
  $logger.error "Database connection failed: #{e.message}"
  raise e
end
