Dir[File.join(__dir__, 'rules', '**', '*.rb')].each do |file|
  require_relative file
end
