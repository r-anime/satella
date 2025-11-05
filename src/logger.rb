require 'logger'

$logger = Logger.new($stdout, level: Logger.const_get(ENV.fetch('LOG_LEVEL_CONSOLE', 'INFO')))
