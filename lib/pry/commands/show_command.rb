class Pry
  Pry::Commands.create_command "show-command" do
    group 'Introspection'
    description "Show the source for CMD."

    def process(*args)
      target = target()

      opts = Slop.parse!(args) do |opt|
        opt.banner unindent <<-USAGE
          Usage: show-command [OPTIONS] [CMD]
          Show the source for command CMD.
          e.g: show-command show-method
        USAGE

        opt.on :l, "line-numbers", "Show line numbers."
        opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        opt.on :h, :help, "This message." do
          output.puts opt.help
        end
      end

      return if opts.present?(:help)

      command_name = args.shift
      if !command_name
        raise CommandError, "You must provide a command name."
      end

      if find_command(command_name)
        block = Pry::Method.new(find_command(command_name).block)

        return unless block.source
        set_file_and_dir_locals(block.source_file)

        output.puts make_header(block)
        output.puts

        code = Pry::Code.from_method(block).with_line_numbers(opts.present?(:'line-numbers')).to_s

        render_output(code, opts)
      else
        raise CommandError, "No such command: #{command_name}."
      end
    end
  end
end
