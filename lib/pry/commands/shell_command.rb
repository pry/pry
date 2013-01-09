class Pry
  class Command::ShellCommand < Pry::ClassCommand
    match /\.(.*)/
    group 'Input and Output'
    description "All text following a '.' is forwarded to the shell."
    command_options :listing => '.<shell command>', :use_prefix => false,
      :takes_block => true

    banner <<-'BANNER'
      Usage: .COMMAND_NAME

      All text following a "." is forwarded to the shell.

      .ls -aF
      .uname
    BANNER

    def process(cmd)
      if cmd =~ /^cd\s+(.+)/i
        dest = $1
        begin
          Dir.chdir File.expand_path(dest)
        rescue Errno::ENOENT
          raise CommandError, "No such directory: #{dest}"
        end
      else
        pass_block(cmd)

        if command_block
          command_block.call `#{cmd}`
        else
          Pry.config.system.call(output, cmd, _pry_)
        end
      end
    end

    def complete(search)
      super + Bond::Rc.files(search.split(" ").last || '')
    end
  end

  Pry::Commands.add_command(Pry::Command::ShellCommand)
end
