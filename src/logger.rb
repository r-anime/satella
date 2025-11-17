require 'logger'
require 'active_support/logger'
require "active_support/broadcast_logger"
require 'fileutils'

STDOUT.sync = true
console_logger = Logger.new(STDOUT, level: Logger.const_get(ENV.fetch('LOG_LEVEL_CONSOLE', 'INFO')))

FileUtils.mkdir_p(File.dirname(ENV["LOG_FILE_SATELLA_MAIN_PATH"]))
file_logger = Logger.new(
  ENV["LOG_FILE_SATELLA_MAIN_PATH"],
  ENV.fetch('LOG_FILE_NUMBER_FILES', "3").to_i,
  ENV.fetch('LOG_FILE_MAX_MEBIBYTES', "1").to_i,
  level: Logger.const_get(ENV.fetch('LOG_LEVEL_FILE', 'INFO'))
)

$logger = ActiveSupport::BroadcastLogger.new(console_logger, file_logger)
