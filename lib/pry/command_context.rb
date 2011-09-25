class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class CommandContext

    # represents a void return value for a command
    VOID_VALUE = Object.new

    # give it a nice inspect
    def VOID_VALUE.inspect() "void" end

    attr_accessor :command_name
    attr_accessor :output
    attr_accessor :target
    attr_accessor :target_self
    attr_accessor :captures
    attr_accessor :eval_string
    attr_accessor :arg_string
    attr_accessor :opts
    attr_accessor :command_set
    attr_accessor :command_processor
    attr_accessor :_pry_

    # Run a command from another command.
    # @param [String] command_string The string that invokes the command
    # @param [Array] args Further arguments to pass to the command
    # @example
    #   run "show-input"
    # @example
    #   run ".ls"
    # @example
    #   run "amend-line",  "5", 'puts "hello world"'
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

    def void
      VOID_VALUE
    end

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers
  end
end
