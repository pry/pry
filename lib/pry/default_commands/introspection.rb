require 'tempfile'

class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      create_command "show-method" do
        description "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source"

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

      create_command "edit" do
        description "Invoke the default editor on a file. Type `edit --help` for more info"

        banner <<-BANNER
          Usage: edit [--no-reload|--reload] [--line LINE] [--temp|--ex|FILE[:LINE]|--in N]

          Open a text editor. When no FILE is given, edits the pry input buffer.
          Ensure Pry.config.editor is set to your editor of choice.

          e.g: `edit sample.rb`
          e.g: `edit sample.rb --line 105`
          e.g: `edit --ex`

          https://github.com/pry/pry/wiki/Editor-integration#wiki-Edit_command
        BANNER

        def options(opt)
          opt.on :e, :ex, "Open the file that raised the most recent exception (_ex_.file)", :optional => true, :as => Integer
          opt.on :i, :in, "Open a temporary file containing the Nth line of _in_. N may be a range.", :optional => true, :as => Range, :default => -1..-1
          opt.on :t, :temp, "Open an empty temporary file"
          opt.on :l, :line, "Jump to this line in the opened file", true, :as => Integer
          opt.on :n, :"no-reload", "Don't automatically reload the edited code"
          opt.on :r, :reload, "Reload the edited code immediately (default for ruby files)"
        end

        def process
          if [opts.present?(:ex), opts.present?(:temp), opts.present?(:in), !args.empty?].count(true) > 1
            raise CommandError, "Only one of --ex, --temp, --in and FILE may be specified."
          end

          if !opts.present?(:ex) && args.empty?
            # edit of local code, eval'd within pry.
            process_local_edit
          else
            # edit of remote code, eval'd at top-level
            process_remote_edit
          end
        end

        def process_i
          case opts[:i]
          when Range
            (_pry_.input_array[opts[:i]] || []).join
          when Fixnum
            _pry_.input_array[opts[:i]] || ""
          else
            return output.puts "Not a valid range: #{opts[:i]}"
          end
        end

        def process_local_edit
          content = case
            when opts.present?(:temp)
              ""
            when opts.present?(:in)
              process_i
            when eval_string.strip != ""
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
        end

        def process_remote_edit
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

      create_command "edit-method" do
        description "Edit a method. Type `edit-method --help` for more info."

        banner <<-BANNER
          Usage: edit-method [OPTIONS] [METH]

          Edit the method METH in an editor.
          Ensure Pry.config.editor is set to your editor of choice.

          e.g: `edit-method hello_method`
          e.g: `edit-method Pry#rep`
          e.g: `edit-method`

          https://github.com/pry/pry/wiki/Editor-integration#wiki-Edit_method
        BANNER

        command_options :shellwords => false

        def options(opt)
          method_options(opt)
          opt.on :n, "no-reload", "Do not automatically reload the method's file after editing."
          opt.on "no-jump", "Do not fast forward editor to first line of method."
          opt.on :p, :patch, "Instead of editing the method's file, try to edit in a tempfile and apply as a monkey patch."
        end

        def process
          if !Pry.config.editor
            raise CommandError, "No editor set!\nEnsure that #{text.bold("Pry.config.editor")} is set to your editor of choice."
          end

          begin
            @method = method_object
          rescue NonMethodContextError => err
          end

          if opts.present?(:patch) || (@method && @method.dynamically_defined?)
            if err
              raise err # can't patch a non-method
            end

            process_patch
          else
            if err && !File.exist?(target.eval('__FILE__'))
              raise err # can't edit a non-file
            end

            process_file
          end
        end

        def process_patch
          lines = @method.source.lines.to_a

          if ((original_name = @method.original_name) &&
              lines[0] =~ /^def (?:.*?\.)?#{original_name}(?=[\(\s;]|$)/)
            lines[0] = "def #{original_name}#{$'}"
          else
            raise CommandError, "Pry can only patch methods created with the `def` keyword."
          end

          temp_file do |f|
            f.puts lines.join
            f.flush
            invoke_editor(f.path, 0)

            if @method.alias?
              with_method_transaction(original_name, @method.owner) do
                Pry.new(:input => StringIO.new(File.read(f.path))).rep(@method.owner)
                Pry.binding_for(@method.owner).eval("alias #{@method.name} #{original_name}")
              end
            else
              Pry.new(:input => StringIO.new(File.read(f.path))).rep(@method.owner)
            end
          end
        end

        def process_file
          file, line = extract_file_and_line

          invoke_editor(file, opts["no-jump"] ? 0 : line)
          silence_warnings do
            load file unless opts.present?(:'no-jump') || Pry.config.disable_auto_reload
          end
        end

        protected
          def extract_file_and_line
            if @method
              if @method.source_type == :c
                raise CommandError, "Can't edit a C method."
              else
                [@method.source_file, @method.source_line]
              end
            else
              [target.eval('__FILE__'), target.eval('__LINE__')]
            end
          end

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

