class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class CommandContext
    attr_accessor :output
    attr_accessor :target
    attr_accessor :opts
    attr_accessor :command_set

    def run(name, *args)
      if name.start_with? "."
        cmd = name[1..-1]

        unless system("#{cmd} #{args.join(' ')}")
          output.puts "Error: there was a problem executing system command: #{cmd}"
        end
      else
        command_set.run_command(self, name, *args)
      end
    end

    def commands
      command_set.commands
    end

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers
  end
end
