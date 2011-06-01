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

    def run(command_string, *args)
      complete_string = "#{command_string} #{args.join(" ")}"
      command_processor.process_commands(complete_string, eval_string, target)
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
