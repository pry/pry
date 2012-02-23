require 'tempfile'

class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      create_command "show-doc", "Show the comments above METH. Aliases: \?", :shellwords => false do |*args|
        banner <<-BANNER
          Usage: show-doc [OPTIONS] [METH]
          Show the comments above method METH. Tries instance methods first and then methods by default.
          e.g show-doc hello_method
        BANNER

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          meth = method_object
          raise Pry::CommandError, "No documentation found." if meth.doc.nil? || meth.doc.empty?

          doc = process_comment_markup(meth.doc, meth.source_type)
          output.puts make_header(meth, doc)
          output.puts "#{text.bold("Owner:")} #{meth.owner || "N/A"}"
          output.puts "#{text.bold("Visibility:")} #{meth.visibility}"
          output.puts "#{text.bold("Signature:")} #{meth.signature}"
          output.puts

          if opts.present?(:b) || opts.present?(:l)
            doc = Code.new(doc, start_line, :text).
              with_line_numbers(true)
          end

          render_output(doc, opts)
        end

        def start_line
          if opts.present?(:'base-one')
             1
          else
            (method_object.source_line - method_object.doc.lines.count) || 1
          end
        end

      end

      alias_command "?", "show-doc"

      create_command "stat", "View method information and set _file_ and _dir_ locals.", :shellwords => false do |*args|
        banner <<-BANNER
            Usage: stat [OPTIONS] [METH]
            Show method information for method METH and set _file_ and _dir_ locals.
            e.g: stat hello_method
        BANNER

        def options(opt)
          method_options(opt)
        end

        def process
          meth = method_object
          output.puts unindent <<-EOS
            Method Information:
            --
            Name: #{meth.name}
            Owner: #{meth.owner ? meth.owner : "Unknown"}
            Visibility: #{meth.visibility}
            Type: #{meth.is_a?(::Method) ? "Bound" : "Unbound"}
            Arity: #{meth.arity}
            Method Signature: #{meth.signature}
            Source Location: #{meth.source_location ? meth.source_location.join(":") : "Not found."}
          EOS
        end
      end

      create_command "show-method" do
        description "Show the source for METH. Aliases: $, show-source"

        banner <<-BANNER
          Usage: show-method [OPTIONS] [METH]
          Aliases: $, show-source

          Show the source for method METH. Tries instance methods first and then methods by default.

          e.g: `show-method hello_method`
          e.g: `show-method -m hello_method`
          e.g: `show-method Pry#rep`

          https://github.com/pry/pry/wiki/Source-browsing#wiki-Show_method
        BANNER

        command_options(
          :shellwords => false
        )

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          raise CommandError, "Could not find method source" unless method_object.source

          output.puts make_header(method_object)
          output.puts "#{text.bold("Owner:")} #{method_object.owner || "N/A"}"
          output.puts "#{text.bold("Visibility:")} #{method_object.visibility}"
          output.puts

          code = Code.from_method(method_object, start_line).
                   with_line_numbers(use_line_numbers?)

          render_output(code, opts)
        end

        def use_line_numbers?
          opts.present?(:b) || opts.present?(:l)
        end

        def start_line
          if opts.present?(:'base-one')
            1
          else
            method_object.source_line || 1
          end
        end
      end

      alias_command "show-source", "show-method"
      alias_command "$", "show-method"

      command "show-command", "Show the source for CMD." do |*args|
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

        next if opts.present?(:help)

        command_name = args.shift
        if !command_name
          raise CommandError, "You must provide a command name."
        end

        if find_command(command_name)
          block = Pry::Method.new(find_command(command_name).block)

          next unless block.source
          set_file_and_dir_locals(block.source_file)

          output.puts make_header(block)
          output.puts

          code = Code.from_method(block).with_line_numbers(opts.present?(:'line-numbers'))

          render_output(code, opts)
        else
          raise CommandError, "No such command: #{command_name}."
        end
      end

      create_command "ri", "View ri documentation. e.g `ri Array#each`" do
        banner <<-BANNER
          Usage: ri [spec]
          e.g. ri Array#each

          Relies on the ri executable being available. See also: show-doc.
        BANNER

        def process
          run ".ri", *args
        end
      end

    end
  end
end

