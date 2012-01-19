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
        raise CommandError, "Provide a command set name" if command_set.nil?

        set = target.eval(arg_string)
        _pry_.commands.import set
      end

      command "reload-method", "Reload the source file that contains the specified method" do |meth_name|
        meth = get_method_or_raise(meth_name, target, {}, :omit_help)

        if meth.source_type == :c
          raise CommandError, "Can't reload a C method."
        elsif meth.dynamically_defined?
          raise CommandError, "Can't reload an eval method."
        else
          file_name = meth.source_file
          load file_name
          output.puts "Reloaded #{file_name}."
        end
      end

      command "req", "Require file(s) and expand their paths." do |*args|
        args.each { |file_name| load File.expand_path(file_name) }
      end

      command "reset", "Reset the REPL to a clean state." do
        if !Pry::Helpers::BaseHelpers.windows?
          if (reset = `which reset`.strip) && !reset.empty?
            system(reset)
          end
        end
        
        output.puts "Pry reset."
        exec "pry"
      end
    end

  end
end
