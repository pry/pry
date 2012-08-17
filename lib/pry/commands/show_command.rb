class Pry
  Pry::Commands.create_command "show-command" do
    group 'Introspection'
    description "Show the source for CMD."

    def process(*args)
      target = target()

      opts = Slop.parse!(args) do |opt|
        opt.banner unindent <<-USAGE
            NOTE: show-command is DEPRACTED. Use show-source [command_name] instead.
        USAGE

        opt.on :h, :help, "This message." do
          output.puts opt.help
        end
      end

      render_output opts.banner
    end
  end
end
