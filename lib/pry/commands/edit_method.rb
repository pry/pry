class Pry
  class Command::EditMethod < Pry::ClassCommand
    match 'edit-method'
    group 'Editing'
    description 'Show the source for CMD.'

    banner <<-'BANNER'
      Show the source for CMD.
    BANNER

    def process(*args)
      target = target()

      opts = Slop.parse!(args) do |opt|
        opt.banner unindent <<-'BANNER'
          NOTE: edit-method is DEPRECATED. Use `edit` instead.
        BANNER

        opt.on :h, :help, "This message" do
          output.puts opt.help
        end
      end

      stagger_output opts.banner
    end
  end

  Pry::Commands.add_command(Pry::Command::EditMethod)
end
