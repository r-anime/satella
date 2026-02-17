require 'logger'
require 'active_support/logger'
require "active_support/broadcast_logger"
require 'fileutils'

# Monkeypatch a 'trace' loglevel into ruby & ActiveSupport Logger: https://gist.github.com/gregretkowski/3873591
class Logger
  new_labels = SEV_LABEL.map.with_index(0) { |label, i| [i, label] }
  new_labels = new_labels.unshift([-1, 'TRACE']).to_h.freeze
  self.send :remove_const, 'SEV_LABEL'
  SEV_LABEL = new_labels

  module Severity
    TRACE = -1
  end

  def trace(progname = nil, &block)
    add(TRACE, nil, progname, &block)
  end

  def trace?
    @level <= TRACE
  end
end

module ActiveSupport
  class BroadcastLogger
    def trace(...)
      dispatch(:trace, ...)
    end
  end
end

STDOUT.sync = true
console_logger = Logger.new(STDOUT, level: Logger.const_get(ENV.fetch('LOG_LEVEL_CONSOLE', 'INFO')))

FileUtils.mkdir_p(File.dirname(ENV["LOG_FILE_SATELLA_MAIN_PATH"]))
file_logger = Logger.new(
  ENV["LOG_FILE_SATELLA_MAIN_PATH"],
  ENV.fetch('LOG_FILE_NUMBER_FILES', "3").to_i,
  ENV.fetch('LOG_FILE_MAX_MEBIBYTES', "1").to_i * 1024 * 1024,
  level: Logger.const_get(ENV.fetch('LOG_LEVEL_FILE', 'INFO'))
)

$logger = ActiveSupport::BroadcastLogger.new(console_logger, file_logger)
