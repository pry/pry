require "pry/default_commands/basic"
require "pry/default_commands/documentation"
require "pry/default_commands/gems"
require "pry/default_commands/context"
require "pry/default_commands/input"
require "pry/default_commands/shell"
require "pry/default_commands/introspection"
require "pry/default_commands/easter_eggs"

require "pry/extended_commands/user_command_api"
require "pry/extended_commands/experimental"

class Pry

  # Default commands used by Pry.
  Commands = Pry::CommandSet.new do
    import DefaultCommands::Basic
    import DefaultCommands::Documentation
    import DefaultCommands::Gems
    import DefaultCommands::Context
    import DefaultCommands::Input
    import DefaultCommands::Shell
    import DefaultCommands::Introspection
    import DefaultCommands::EasterEggs
  end
end
