class Pry
  module DefaultCommands

    Basic = Pry::CommandSet.new do
      command "toggle-color", "Toggle syntax highlighting." do
        Pry.color = !Pry.color
        output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
      end

      command "simple-prompt", "Toggle the simple prompt." do
        case Pry.active_instance.prompt
        when Pry::SIMPLE_PROMPT
          Pry.active_instance.prompt = Pry::DEFAULT_PROMPT
        else
          Pry.active_instance.prompt = Pry::SIMPLE_PROMPT
        end
      end

      command "version", "Show Pry version." do
        output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
      end

      command "import", "Import a command set" do |command_set_name|
        next output.puts "Provide a command set name" if command_set.nil?

        set = target.eval(opts[:arg_string])
        Pry.active_instance.commands.import set
      end

    end

  end
end
