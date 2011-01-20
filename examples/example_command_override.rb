direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

# inherit standard command set, but tweak them by deleting some and
# overriding others
class MyCommands < Pry::CommandBase

  # Override ls command
  command "ls", "An unhelpful ls" do
    output.puts "No, i refuse to display any useful information."
  end

  # Invoke one command from within another using `run`
  command "status2" do |x|
    output.puts "About to show status, are you ready?"
    run "status", x
    output.puts "Finished showing status."
  end

  import_from Pry::Commands, "quit", "show_method", "ls"
end

# Start a Pry session using the commands defined in MyCommands
# Type 'help' in Pry to get a list of the commands and their descriptions
Pry.start(TOPLEVEL_BINDING, :commands => MyCommands)
