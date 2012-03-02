require "pry/default_commands/misc"
require "pry/default_commands/help"
require "pry/default_commands/gems"
require "pry/default_commands/context"
require "pry/default_commands/commands"
require "pry/default_commands/input_and_output"
require "pry/default_commands/introspection"
require "pry/default_commands/editing"
require "pry/default_commands/navigating_pry"
require "pry/default_commands/easter_eggs"

require "pry/extended_commands/experimental"

class Pry

  # Default commands used by Pry.
  Commands = Pry::CommandSet.new do
    import DefaultCommands::Misc
    import DefaultCommands::Help
    import DefaultCommands::Gems
    import DefaultCommands::Context
    import DefaultCommands::NavigatingPry
    import DefaultCommands::Editing
    import DefaultCommands::InputAndOutput
    import DefaultCommands::Introspection
    import DefaultCommands::EasterEggs
    import DefaultCommands::Commands
  end
end
