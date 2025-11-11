require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'],
  port: ENV['DB_PORT'],
  database: ENV['DB_NAME'],
  username: ENV['DB_USER'],
  password: ENV['DB_PASSWORD']
)

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger.const_get(ENV.fetch('LOG_LEVEL_DB', 'INFO'))
Dir[File.join(__dir__, 'models', '**', '*.rb')].each do |file|
  require_relative file
end

begin
  ActiveRecord::Base.connection.execute("SELECT 1")
  $logger.info "Successfully connected to postgres"
rescue => e
  $logger.error  "Database connection failed: #{e.message}"
  raise e
end
