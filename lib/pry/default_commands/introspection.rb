require 'tempfile'

class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: show-method [OPTIONS] [METH 1] [METH 2] [METH N]
            Show the source for method METH. Tries instance methods first and then methods by default.
            e.g: show-method hello_method
          USAGE

          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        args = [nil] if args.empty?
        args.each do |method_name|
          meth_name = method_name
          if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
            output.puts "Invalid method name: #{meth_name}. Type `show-method --help` for help"
            next
          end

          code, code_type = code_and_code_type_for(meth)
          next if !code

          output.puts make_header(meth, code_type, code)
          if Pry.color
            code = CodeRay.scan(code, code_type).term
          end

          start_line = false
          if opts.l?
            start_line = meth.source_location ? meth.source_location.last : 1
          end

          start_line = opts.b? ? 1 : start_line


          render_output(opts.flood?, start_line, code)
          code
        end
      end

      alias_command "show-source", "show-method", ""
      alias_command "$", "show-method", ""

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
            output.puts opt
          end
        end

        next if opts.help?

        command_name = args.shift
        if !command_name
          output.puts "You must provide a command name."
          next
        end

        if find_command(command_name)
          block = find_command(command_name).block

          code, _ = code_and_code_type_for(block)
          next if !code

          output.puts make_header(block, :ruby, code)

          if Pry.color
            code = CodeRay.scan(code, :ruby).term
          end

          start_line = false
          if opts.l?
            start_line = block.source_location ? block.source_location.last : 1
          end

          render_output(opts.flood?, opts.l? ? block.source_location.last : false, code)
          code
        else
          output.puts "No such command: #{command_name}."
        end
      end

      command "edit", "Invoke the default editor on a file. Type `edit --help` for more info" do |*args|
        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: edit [--no-reload|--reload] [--line LINE] [--temp|--ex|FILE[:LINE]]
            Open a text editor. When no FILE is given, edits the pry input buffer.
            Ensure #{text.bold("Pry.config.editor")} is set to your editor of choice.
            e.g: edit sample.rb
          USAGE

          opt.on :e, :ex, "Open the file that raised the most recent exception (_ex_.file)", :optional => true, :as => Integer
          opt.on :t, :temp, "Open an empty temporary file"
          opt.on :l, :line, "Jump to this line in the opened file", true, :as => Integer
          opt.on :n, :"no-reload", "Don't automatically reload the edited code"
          opt.on :r, :reload, "Reload the edited code immediately (default for ruby files)"
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end
        next if opts.h?

        if [opts.ex? || nil, opts.t? || nil, !args.empty? || nil].compact.size > 1
          next output.puts "Only one of --ex, --temp, and FILE may be specified"
        end

        # edit of local code, eval'd within pry.
        if !opts.ex? && args.empty?

          content = if opts.t?
                      ""
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
            if !opts.n?
              silence_warnings do
                eval_string.replace(File.read(f.path))
              end
            end
          end

        # edit of remote code, eval'd at top-level
        else
          if opts.ex?
            next output.puts "No Exception found." if _pry_.last_exception.nil?
            ex = _pry_.last_exception
            bt_index = opts[:ex].to_i

            ex_file, ex_line = ex.bt_source_location_for(bt_index)
            if ex_file && is_core_rbx_path?(ex_file)
              file_name = rbx_convert_path_to_full(ex_file)
            else
              file_name = ex_file
            end

            line = ex_line
            next output.puts "Exception has no associated file." if file_name.nil?
            next output.puts "Cannot edit exceptions raised in REPL." if Pry.eval_path == file_name

          else
            # break up into file:line
            file_name = File.expand_path(args.first)

            line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
          end

          line = opts[:l].to_i if opts.l?

          invoke_editor(file_name, line)
          set_file_and_dir_locals(file_name)

          if opts.r? || ((opts.ex? || file_name.end_with?(".rb")) && !opts.n?)
            silence_warnings do
              TOPLEVEL_BINDING.eval(File.read(file_name), file_name)
            end
          end
        end
      end

      command "edit-method", "Edit a method. Type `edit-method --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: edit-method [OPTIONS] [METH]
            Edit the method METH in an editor.
            Ensure #{text.bold("Pry.config.editor")} is set to your editor of choice.
            e.g: edit-method hello_method
          USAGE

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :n, "no-reload", "Do not automatically reload the method's file after editing."
          opt.on "no-jump", "Do not fast forward editor to first line of method."
          opt.on :p, :patch, "Instead of editing the method's file, try to edit in a tempfile and apply as a monkey patch."
          opt.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        if !Pry.config.editor
          output.puts "Error: No editor set!"
          output.puts "Ensure that #{text.bold("Pry.config.editor")} is set to your editor of choice."
          next
        end

        meth_name = args.shift
        meth_name, target, type = get_method_attributes(meth_name, target, opts.to_hash(true))
        meth = get_method_object_from_target(meth_name, target, type)

        if meth.nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        if opts.p? || is_a_dynamically_defined_method?(meth)
          code, _ = code_and_code_type_for(meth)

          lines = code.lines.to_a
          if lines[0] =~ /^def [^( \n]+/
            lines[0] = "def #{meth_name}#{$'}"
          else
            next output.puts "Error: Pry can only patch methods created with the `def` keyword."
          end

          temp_file do |f|
            f.puts lines.join
            f.flush
            invoke_editor(f.path, 0)
            Pry.new(:input => StringIO.new(File.read(f.path))).rep(meth.owner)
          end
          next
        end

        if is_a_c_method?(meth)
          output.puts "Error: Can't edit a C method."
        else
          file, line = path_line_for(meth)
          set_file_and_dir_locals(file)

          invoke_editor(file, opts["no-jump"] ? 0 : line)
          silence_warnings do
            load file if !opts.n? && !Pry.config.disable_auto_reload
          end
        end
      end

    end
  end
end

