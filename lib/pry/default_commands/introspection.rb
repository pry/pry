require 'tempfile'

class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: show-method [OPTIONS] [METH 1] [METH 2] [METH N]\n" \
                     "Show the source for method METH. Tries instance methods first and then methods by default.\n" \
                     "e.g: show-method hello_method"

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
          opt.banner = "Usage: show-command [OPTIONS] [CMD]\n" \
                       "Show the source for command CMD.\n" \
                       "e.g: show-command show-method"

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
          opt.banner "Usage: edit [OPTIONS] [FILE]\n" \
                      "Edit the method FILE in an editor.\n" \
                      "Ensure #{text.bold("Pry.editor")} is set to your editor of choice.\n" \
                      "e.g: edit sample.rb"

          opt.on :r, "reload", "Eval file content after editing (evals at top level)"
          opt.on :ex, "Open an editor at the line and file that generated the most recent Exception."
          opt.on :t, "temp", "Open a temporary file in an editor and eval it in current context after closing."
          opt.on :p, "play", "Use the pry `play` command to eval the file content after editing."
          opt.on :l, "line", "Specify line number to jump to in file", true, :as => Integer
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end
        next if opts.h?

        # the context the file will be eval'd in after closing
        context = TOPLEVEL_BINDING
        should_reload = opts[:r]

        if opts.ex?
          next output.puts "No Exception found." if Pry.last_exception.nil?

          file_name = Pry.last_exception.file
          line = Pry.last_exception.line
          next output.puts "Exception has no associated file." if file_name.nil?
          next output.puts "Cannot edit exceptions raised in REPL." if Pry.eval_path == file_name
        elsif opts.t?
          file_name = Tempfile.new(["tmp", ".rb"]).tap(&:close).path
          line = 0
          should_reload = true
          context = target
        else
          next output.puts("Need to specify a file.") if !args.first
          file_name = File.expand_path(args.first)
          line = opts[:l].to_i
        end

        invoke_editor(file_name, line)
        set_file_and_dir_locals(file_name)

        if opts[:p]
          silence_warnings do
            _pry_.input = StringIO.new(File.readlines(file_name).join)
          end
        elsif should_reload
          silence_warnings do
            context.eval(File.read(file_name), file_name)
          end
        end
      end

      command "edit-method", "Edit a method. Type `edit-method --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: edit-method [OPTIONS] [METH]\n" \
                      "Edit the method METH in an editor.\n" \
                      "Ensure #{text.bold("Pry.editor")} is set to your editor of choice.\n" \
                      "e.g: edit-method hello_method"

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :n, "no-reload", "Do not automatically reload the method's file after editing."
          opt.on "no-jump", "Do not fast forward editor to first line of method."
          opt.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        next output.puts "Error: No editor set!\nEnsure that #{text.bold("Pry.editor")} is set to your editor of choice." if !Pry.editor

        if is_a_c_method?(meth)
          output.puts "Error: Can't edit a C method."
        elsif is_a_dynamically_defined_method?(meth)
          output.puts "Error: Can't edit an eval method."

          # editor is invoked here
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

