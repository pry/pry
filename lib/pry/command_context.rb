class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class CommandContext
    attr_accessor :output
    attr_accessor :target
    attr_accessor :captures
    attr_accessor :eval_string
    attr_accessor :arg_string
    attr_accessor :opts
    attr_accessor :command_set
    attr_accessor :command_processor

    def run(name, *args)
      command_set.run_command(self, name, *args)
    end

    def commands
      command_set.commands
    end

    def text
      Pry::Helpers::Text
    end

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers
  end
end
