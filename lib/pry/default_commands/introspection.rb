class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new do

      command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: show-method [OPTIONS] [METH]\n" \
                     "Show the source for method METH. Tries instance methods first and then methods by default.\n" \
                     "e.g: show-method hello_method"

          opt.on :l, "line-numbers", "Show line numbers."
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

        meth_name = args.shift
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

        render_output(opts.flood?, start_line, code)
        code
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

      command "edit-method", "Edit a method. Type `edit-method --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: edit-method [OPTIONS] [METH]\n" \
                      "Edit the method METH in an editor.\n" \
                      "Ensure #{text.bold("Pry.editor")} is set to your editor of choice.\n" \
                      "e.g: edit-method hello_method"

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :n, "no-reload", "Do not automatically reload the method's file after editting."
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

          if Pry.editor.respond_to?(:call)
            editor_invocation = Pry.editor.call(file, line)
          else
            # only use start line if -n option is not used
            start_line_syntax = opts["no-jump"] ? "" : start_line_for_editor(file, line)
            editor_invocation = "#{Pry.editor} #{start_line_syntax}"
          end

          run ".#{editor_invocation}"
          silence_warnings do
            load file if !opts.n?
          end
        end
      end

      helpers do

        def start_line_for_editor(file_name, line_number)
          file_name.gsub!(/\//, '\\') if RUBY_PLATFORM =~ /mswin|mingw/

          case Pry.editor
          when /^[gm]?vi/, /^emacs/, /^nano/, /^pico/, /^gedit/, /^kate/
            "+#{line_number} #{file_name}"
          when /^mate/, /^geany/
            "-l #{line_number} #{file_name}"
          when /^uedit32/
            "#{file_name}/#{line_number}"
          when /^jedit/
            "#{file_name} +#{line_number}"
          else
            if RUBY_PLATFORM =~ /mswin|mingw/
              "#{file_name}"
            else
              "+#{line_number} #{file_name}"
            end
          end
        end

      end

    end
  end
end

