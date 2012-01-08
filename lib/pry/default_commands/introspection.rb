require 'tempfile'

class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      command_class "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source", :shellwords => false do |*args|
        banner <<-BANNER
          Usage: show-method [OPTIONS] [METH]
          Show the source for method METH. Tries instance methods first and then methods by default.
          e.g: show-method hello_method
        BANNER

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          meth = method_object
          raise CommandError, "Could not find method source" unless meth.source

          output.puts make_header(meth)
          output.puts "#{text.bold("Owner:")} #{meth.owner || "N/A"}"
          output.puts "#{text.bold("Visibility:")} #{meth.visibility}"
          output.puts

          if opts.present?(:'base-one')
            start_line = 1
          else
            start_line = meth.source_line || 1
          end

          code = Code.from_method(meth, start_line).
                   with_line_numbers(opts.present?(:b) || opts.present?(:l))

          render_output(code, opts)
        end
      end

      alias_command "show-source", "show-method"
      alias_command "$", "show-method"

      command "show-command", "Show the source for CMD. Type `show-command --help` for more info." do |*args|
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

      command "edit", "Invoke the default editor on a file. Type `edit --help` for more info" do |*args|
        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: edit [--no-reload|--reload] [--line LINE] [--temp|--ex|FILE[:LINE]|--in N]
            Open a text editor. When no FILE is given, edits the pry input buffer.
            Ensure #{text.bold("Pry.config.editor")} is set to your editor of choice.
            e.g: edit sample.rb
          USAGE

          opt.on :e, :ex, "Open the file that raised the most recent exception (_ex_.file)", :optional => true, :as => Integer
          opt.on :i, :in, "Open a temporary file containing the Nth line of _in_. N may be a range.", :optional => true, :as => Range, :default => -1..-1
          opt.on :t, :temp, "Open an empty temporary file"
          opt.on :l, :line, "Jump to this line in the opened file", true, :as => Integer
          opt.on :n, :"no-reload", "Don't automatically reload the edited code"
          opt.on :r, :reload, "Reload the edited code immediately (default for ruby files)"
          opt.on :h, :help, "This message." do
            output.puts opt.help
          end
        end
        next if opts.present?(:help)

        if [opts.present?(:ex), opts.present?(:temp), opts.present?(:in), !args.empty?].count(true) > 1
          raise CommandError, "Only one of --ex, --temp, --in and FILE may be specified."
        end

        # edit of local code, eval'd within pry.
        if !opts.present?(:ex) && args.empty?

          content = if opts.present?(:temp)
                      ""
                    elsif opts.present?(:in)
                      case opts[:i]
                      when Range
                        (_pry_.input_array[opts[:i]] || []).join
                      when Fixnum
                        _pry_.input_array[opts[:i]] || ""
                      else
                        next output.puts "Not a valid range: #{opts[:i]}"
                      end
                    elsif eval_string.strip != ""
                      eval_string
                    else
                      _pry_.input_array.reverse_each.find{ |x| x && x.strip != "" } || ""
                    end

          line = content.lines.count

          temp_file do |f|
            f.puts(content)
            f.flush
            invoke_editor(f.path, line)
            if !opts.present?(:'no-reload')
              silence_warnings do
                eval_string.replace(File.read(f.path))
              end
            end
          end

        # edit of remote code, eval'd at top-level
        else
          if opts.present?(:ex)
            if _pry_.last_exception.nil?
              raise CommandError, "No exception found."
            end

            ex = _pry_.last_exception
            bt_index = opts[:ex].to_i

            ex_file, ex_line = ex.bt_source_location_for(bt_index)
            if ex_file && RbxPath.is_core_path?(ex_file)
              file_name = RbxPath.convert_path_to_full(ex_file)
            else
              file_name = ex_file
            end

            line = ex_line

            if file_name.nil?
              raise CommandError, "Exception has no associated file."
            end

            if Pry.eval_path == file_name
              raise CommandError, "Cannot edit exceptions raised in REPL."
            end
          else
            # break up into file:line
            file_name = File.expand_path(args.first)

            line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
          end

          line = opts[:l].to_i if opts.present?(:line)

          invoke_editor(file_name, line)
          set_file_and_dir_locals(file_name)

          if opts.present?(:reload) || ((opts.present?(:ex) || file_name.end_with?(".rb")) && !opts.present?(:'no-reload'))
            silence_warnings do
              TOPLEVEL_BINDING.eval(File.read(file_name), file_name)
            end
          end
        end
      end

      command_class "edit-method", "Edit a method. Type `edit-method --help` for more info.", :shellwords => false do |*args|

        def options(opt)
          opt.banner unindent <<-BANNER
            Usage: edit-method [OPTIONS] [METH]
            Edit the method METH in an editor.
            Ensure #{text.bold("Pry.config.editor")} is set to your editor of choice.
            e.g: edit-method hello_method
          BANNER
          method_options(opt)
          opt.on :n, "no-reload", "Do not automatically reload the method's file after editing."
          opt.on "no-jump", "Do not fast forward editor to first line of method."
          opt.on :p, :patch, "Instead of editing the method's file, try to edit in a tempfile and apply as a monkey patch."
        end

        def process
          meth = method_object
          if !Pry.config.editor
            raise CommandError, "No editor set!\nEnsure that #{text.bold("Pry.config.editor")} is set to your editor of choice."
          end

          if opts.present?(:patch) || meth.dynamically_defined?
            lines = meth.source.lines.to_a

            if ((original_name = meth.original_name) &&
                lines[0] =~ /^def (?:.*?\.)?#{original_name}(?=[\(\s;]|$)/)
              lines[0] = "def #{original_name}#{$'}"
            else
              raise CommandError, "Pry can only patch methods created with the `def` keyword."
            end

            temp_file do |f|
              f.puts lines.join
              f.flush
              invoke_editor(f.path, 0)

              if meth.alias?
                with_method_transaction(original_name, meth.owner) do
                  Pry.new(:input => StringIO.new(File.read(f.path))).rep(meth.owner)
                  Pry.binding_for(meth.owner).eval("alias #{meth.name} #{original_name}")
                end
              else
                Pry.new(:input => StringIO.new(File.read(f.path))).rep(meth.owner)
              end
            end
            return
          end

          if meth.source_type == :c
            raise CommandError, "Can't edit a C method."
          else
            file, line = meth.source_file, meth.source_line

            invoke_editor(file, opts["no-jump"] ? 0 : line)
            silence_warnings do
              load file if !opts.present?(:'no-jump') && !Pry.config.disable_auto_reload
            end
          end
        end
      end

      helpers do
        def with_method_transaction(meth_name, target=TOPLEVEL_BINDING)
          target = Pry.binding_for(target)
          temp_name = "__pry_#{meth_name}__"

          target.eval("alias #{temp_name} #{meth_name}")
          yield
          target.eval("alias #{meth_name} #{temp_name}")
        ensure
          target.eval("undef #{temp_name}") rescue nil
        end
      end
    end
  end
end

