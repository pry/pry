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
        cmd = Pry.config.commands.commands[command_name]
        load cmd.block.source_location.first
        Pry.config.commands.import target.eval(set_name)
        Pry.active_instance.commands.import target.eval(set_name)
      end

      command "edit-command", "Edit a command. edit-command CMD_NAME CMD_SET" do |command_name, set_name|
        cmd = Pry.config.commands.commands[command_name]
        invoke_editor(*cmd.block.source_location)
        load cmd.block.source_location.first
        Pry.config.commands.import target.eval(set_name)
        Pry.active_instance.commands.import target.eval(set_name)
      end

    end
  end
end
