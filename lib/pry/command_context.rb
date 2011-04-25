class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class CommandContext
    attr_accessor :output
    attr_accessor :target
    attr_accessor :opts
    attr_accessor :commands

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers
  end
end
