# Default commands used by Pry.
Pry::Commands = Pry::CommandSet.new
Dir[File.expand_path(File.join('commands', '*.rb'), File.dirname(__FILE__))].each do |abspath|
  require_relative File.join('commands', File.basename(abspath))
end
