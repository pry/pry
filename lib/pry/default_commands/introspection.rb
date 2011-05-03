class Pry
  module DefaultCommands

    Introspection = Pry::CommandSet.new :introspection do

      command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opts|
          opts.banner %{Usage: show-method [OPTIONS] [METH]
Show the source for method METH. Tries instance methods first and then methods by default.
e.g: show-method hello_method
--
}
          opts.on :l, "line-numbers", "Show line numbers."
          opts.on :M, "instance-methods", "Operate on instance methods."
          opts.on :m, :methods, "Operate on methods."
          opts.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opts.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opts.on :h, :help, "This message." do
            output.puts opts
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
        options = {}
        target = target()
        command_name = nil

        OptionParser.new do |opts|
          opts.banner = %{Usage: show-command [OPTIONS] [CMD]
Show the source for command CMD.
e.g: show-command show-method
--
}
          opts.on("-l", "--line-numbers", "Show line numbers.") do |line|
            options[:l] = true
          end

          opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
            options[:f] = true
          end

          opts.on_tail("-h", "--help", "This message.") do
            output.puts opts
            options[:h] = true
          end
        end.order(args) do |v|
          command_name = v
        end

        next if options[:h]

        if !command_name
          output.puts "You must provide a command name."
          next
        end

        if commands[command_name]
          meth = commands[command_name].block

          code = strip_leading_whitespace(meth.source)
          file, line = meth.source_location
          set_file_and_dir_locals(file)
          check_for_dynamically_defined_method(meth)

          output.puts make_header(meth, :ruby, code)

          if Pry.color
            code = CodeRay.scan(code, :ruby).term
          end

          render_output(options[:f], options[:l] ? meth.source_location.last : false, code)
          code
        else
          output.puts "No such command: #{command_name}."
        end
      end

      command "edit-method", "Edit a method. Type `edit-method --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opts|
          opts.banner %{Usage: edit-method [OPTIONS] [METH]
Edit the method METH in an editor.
Ensure #{bold("Pry.editor")} is set to your editor of choice.
e.g: edit-method hello_method
--
}
          opts.on :M, "instance-methods", "Operate on instance methods."
          opts.on :m, :methods, "Operate on methods."
          opts.on "no-reload", "Do not automatically reload the method's file after editting."
          opts.on :n, "no-jump", "Do not fast forward editor to first line of method."
          opts.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opts.on :h, :help, "This message." do
            output.puts opts
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        next output.puts "Error: No editor set!\nEnsure that #{bold("Pry.editor")} is set to your editor of choice." if !Pry.editor

        if is_a_c_method?(meth)
          output.puts "Error: Can't edit a C method."
        elsif is_a_dynamically_defined_method?(meth)
          output.puts "Error: Can't edit an eval method."

          # editor is invoked here
        else
          file, line = meth.source_location

          if Pry.editor.respond_to?(:call)
            editor_invocation = Pry.editor.call(file, line)
          else
            # only use start line if -n option is not used
            start_line_syntax = opts.n? ? "" : start_line_for_editor(line)
            editor_invocation = "#{Pry.editor} #{start_line_syntax} #{file}"
          end

          run ".#{editor_invocation}"
          load file if !opts["no-reload"]
        end
      end


    end

  end
end

