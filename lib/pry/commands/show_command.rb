class Pry
  class Command::ShowCommand < Pry::ClassCommand
    match 'show-command'
    group 'Introspection'
    description 'Show the source for CMD.'

    banner <<-'BANNER'
      Show the source for CMD.
    BANNER

    def process(*args)
      target = target()

      opts = Slop.parse!(args) do |opt|
        opt.banner unindent <<-'BANNER'
          NOTE: show-command is DEPRECATED. Use show-source [command_name] instead.
        BANNER

        opt.on :h, :help, "This message" do
          output.puts opt.help
        end
      end

      render_output opts.banner
    end
  end

  Pry::Commands.add_command(Pry::Command::ShowCommand)
end
