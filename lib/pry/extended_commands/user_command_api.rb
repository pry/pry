class Pry
  module ExtendedCommands

    UserCommandAPI = Pry::CommandSet.new do

      command "define-command", "Define a command in the session, use same syntax as `command` method for command API" do |arg|
        next output.puts("Provide an arg!") if arg.nil?

        prime_string = "command #{arg_string}\n"
        command_string = Pry.active_instance.r(target, prime_string)

        eval_string.replace <<-HERE
          _pry_.commands.instance_eval do
            #{command_string}
          end
        HERE

      end

      command "reload-command", "Reload a command. reload-command CMD_NAME CMD_SET" do |command_name, set_name|
        next output.puts "Must provide command name" if command_name.nil?
        next output.puts "Must provide command set name" if set_name.nil?

        cmd = Pry.config.commands.commands[command_name]
        file_name = cmd.block.source_location.first

        silence_warnings do
          load file_name
        end
        Pry.config.commands.import target.eval(set_name)
        Pry.active_instance.commands.import target.eval(set_name)
        set_file_and_dir_locals(file_name)
      end

      command "edit-command", "Edit a command. edit-command CMD_NAME CMD_SET" do |command_name, set_name|
        next output.puts "Must provide command name" if command_name.nil?
        next output.puts "Must provide a command set name" if set_name.nil?

        cmd = Pry.config.commands.commands[command_name]
        file_name = cmd.block.source_location.first

        invoke_editor(*cmd.block.source_location)
        silence_warnings do
          load file_name
        end
        Pry.config.commands.import target.eval(set_name)
        Pry.active_instance.commands.import target.eval(set_name)
        set_file_and_dir_locals(file_name)
      end

    end
  end
end
