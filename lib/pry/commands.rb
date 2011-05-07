require "pry/default_commands/documentation"
require "pry/default_commands/gems"
require "pry/default_commands/context"
require "pry/default_commands/input"
require "pry/default_commands/shell"
require "pry/default_commands/introspection"
require "pry/default_commands/easter_eggs"

class Pry

  # Default commands used by Pry.
  Commands = Pry::CommandSet.new do
    import DefaultCommands::Documentation
    import DefaultCommands::Gems
    import DefaultCommands::Context
    import DefaultCommands::Input, DefaultCommands::Shell
    import DefaultCommands::Introspection
    import DefaultCommands::EasterEggs

    Helpers::CommandHelpers.try_to_load_pry_doc

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

    command "status", "Show status information." do
      nesting = opts[:nesting]

      output.puts "Status:"
      output.puts "--"
      output.puts "Receiver: #{Pry.view_clip(target.eval('self'))}"
      output.puts "Nesting level: #{nesting.level}"
      output.puts "Pry version: #{Pry::VERSION}"
      output.puts "Ruby version: #{RUBY_VERSION}"

      mn = meth_name_from_binding(target)
      output.puts "Current method: #{mn ? mn : "N/A"}"
      output.puts "Pry instance: #{Pry.active_instance}"
      output.puts "Last result: #{Pry.view(Pry.last_result)}"
    end


    command "req", "Requires gem(s). No need for quotes! (If the gem isn't installed, it will ask if you want to install it.)" do |*gems|
      gems = gems.join(' ').gsub(',', '').split(/\s+/)
      gems.each do |gem|
        begin
          if require gem
            output.puts "#{bright_yellow(gem)} loaded"
          else
            output.puts "#{bright_white(gem)} already loaded"
          end

        rescue LoadError => e

          if gem_installed? gem
            output.puts e.inspect
          else
            output.puts "#{bright_red(gem)} not found"
            if prompt("Install the gem?") == "y"
              run "gem-install", gem
            end
          end

        end # rescue
      end # gems.each
    end

    command "version", "Show Pry version." do
      output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
    end


    command "lls", "List local files using 'ls'" do |*args|
      cmd = ".ls"
      run cmd, *args
    end

    command "lcd", "Change the current (working) directory" do |*args|
      run ".cd", *args
    end


    command "eval-file", "Eval a Ruby script. Type `eval-file --help` for more info." do |*args|
      options = {}
      target = target()
      file_name = nil

      OptionParser.new do |opts|
        opts.banner = %{Usage: eval-file [OPTIONS] FILE
Eval a Ruby script at top-level or in the specified context. Defaults to top-level.
e.g: eval-file -c self "hello.rb"
--
}
        opts.on("-c", "--context CONTEXT", "Eval the script in the specified context.") do |context|
          options[:c] = true
          target = Pry.binding_for(target.eval(context))
        end

        opts.on_tail("-h", "--help", "This message.") do
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        file_name = v
      end

      next if options[:h]

      if !file_name
        output.puts "You need to specify a file name. Type `eval-file --help` for help"
        next
      end

      old_constants = Object.constants
      if options[:c]
        target_self = target.eval('self')
        target.eval(File.read(File.expand_path(file_name)))
        output.puts "--\nEval'd '#{file_name}' in the `#{target_self}`  context."
      else
        TOPLEVEL_BINDING.eval(File.read(File.expand_path(file_name)))
        output.puts "--\nEval'd '#{file_name}' at top-level."
      end
      set_file_and_dir_locals(file_name)

      new_constants = Object.constants - old_constants
      output.puts "Brought in the following top-level constants: #{new_constants.inspect}" if !new_constants.empty?
    end

end
end
