require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

# Inherit standard command set, but tweak them by importing some and
# overriding others.
# Illustrates use of `command`, `run`, and `import_from` commands.
class MyCommands < Pry::CommandBase

  # Override ls command
  command "ls", "An unhelpful ls" do
    output.puts "No, i refuse to display any useful information."
  end

  # bring in just the status command from Pry::Commands
  import_from Pry::Commands, "status"

  # analogy to Ruby's native alias_method idiom for decorating a method
  alias_command "old_status", "status"

  # Invoke one command from within another using `run`
  command "status", "Modified status."  do |x|
    output.puts "About to show status, are you ready?"
    run "old_status", x
    output.puts "Finished showing status."
  end

  # bring in a few other commands
  import_from Pry::Commands, "quit", "show-method"
end

# Start a Pry session using the commands defined in MyCommands
# Type 'help' in Pry to get a list of the commands and their descriptions
Pry.start(TOPLEVEL_BINDING, :commands => MyCommands)
