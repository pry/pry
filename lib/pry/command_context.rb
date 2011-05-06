class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class CommandContext
    attr_accessor :output
    attr_accessor :target
    attr_accessor :opts
    attr_accessor :command_set
    attr_accessor :command_processor

    def run(name, *args)
      if name.start_with? "."
        cmd = name[1..-1]
        command_processor.
          execute_system_command([name, Shellwords.join(args)].join(' '),
                                 target)
      else
        command_set.run_command(self, name, *args)
      end
    end

    def commands
      command_set.commands
    end

    def text
      @text ||= Class.new do
        extend Pry::Helpers::Text
      end
    end

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers
  end
end
