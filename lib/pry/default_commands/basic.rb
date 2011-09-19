class Pry
  module DefaultCommands

    Basic = Pry::CommandSet.new do
      command "toggle-color", "Toggle syntax highlighting." do
        Pry.color = !Pry.color
        output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
      end

      command "simple-prompt", "Toggle the simple prompt." do
        case _pry_.prompt
        when Pry::SIMPLE_PROMPT
          _pry_.pop_prompt
        else
          _pry_.push_prompt Pry::SIMPLE_PROMPT
        end
      end

      command "pry-version", "Show Pry version." do
        output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
      end

      command "import-set", "Import a command set" do |command_set_name|
        next output.puts "Provide a command set name" if command_set.nil?

        set = target.eval(arg_string)
        _pry_.commands.import set
      end

      command "reload-method", "Reload the source file that contains the specified method" do |meth_name|
        if (method = Pry::Method.from_str(meth_name, target)).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        if method.source_type == :c
          output.puts "Error: Can't reload a C method."
        elsif method.dynamically_defined?
          output.puts "Error: Can't reload an eval method."
        else
          file_name = method.source_file
          load file_name
          output.puts "Reloaded #{file_name}."
        end
      end

      command "req", "Require file(s) and expand their paths." do |*args|
        args.each { |file_name| load File.expand_path(file_name) }
      end

      command "reset", "Reset the REPL to a clean state." do
        output.puts "Pry reset."
        exec "pry"
      end
    end

  end
end
