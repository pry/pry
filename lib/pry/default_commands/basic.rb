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

      command "command", "To honor Mon-Ouie" do |arg|
        next output.puts("Provide an arg!") if arg.nil?

        prime_string = "command #{opts[:arg_string]}\n"
        command_string = Pry.active_instance.r(target, prime_string)

        opts[:eval_string].replace <<-HERE
          _pry_.commands.instance_eval do
            #{command_string}
          end
        HERE

      end
    end

  end
end
