require "pry/default_commands/ls"

class Pry
  module DefaultCommands

    Context = Pry::CommandSet.new do
      import Ls

      create_command "cd" do
        description "Move into a new context (object or scope). Type `cd --help` for more information."

        banner <<-BANNER
          Usage: cd [OPTIONS] [--help]

          Move into new context (object or scope). As in unix shells use
          `cd ..` to go back and `cd /` to return to Pry top-level).
          Complex syntax (e.g cd ../@x/y) also supported.

          e.g: `cd @x`
          e.g: `cd ..
          e.g: `cd /`

          https://github.com/pry/pry/wiki/State-navigation#wiki-Changing_scope
        BANNER

        def process
          path   = arg_string.split(/\//)
          stack  = _pry_.binding_stack.dup

          # special case when we only get a single "/", return to root
          stack  = [stack.first] if path.empty?

          path.each do |context|
            begin
              case context.chomp
              when ""
                stack = [stack.first]
              when "::"
                stack.push(TOPLEVEL_BINDING)
              when "."
                next
              when ".."
                unless stack.size == 1
                  stack.pop
                end
              else
                stack.push(Pry.binding_for(stack.last.eval(context)))
              end

            rescue RescuableException => e
              output.puts "Bad object path: #{arg_string.chomp}. Failed trying to resolve: #{context}"
              output.puts e.inspect
              return
            end
          end

          _pry_.binding_stack = stack
        end
      end

      command "switch-to", "Start a new sub-session on a binding in the current stack (numbered by nesting)." do |selection|
        selection = selection.to_i

        if selection < 0 || selection > _pry_.binding_stack.size - 1
          raise CommandError, "Invalid binding index #{selection} - use `nesting` command to view valid indices."
        else
          Pry.start(_pry_.binding_stack[selection])
        end
      end

      command "nesting", "Show nesting information." do
        output.puts "Nesting status:"
        output.puts "--"
        _pry_.binding_stack.each_with_index do |obj, level|
          if level == 0
            output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))} (Pry top level)"
          else
            output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))}"
          end
        end
      end

      command "jump-to", "Jump to a binding further up the stack, popping all bindings below." do |break_level|
        break_level = break_level.to_i
        nesting_level = _pry_.binding_stack.size - 1

        case break_level
        when nesting_level
          output.puts "Already at nesting level #{nesting_level}"
        when (0...nesting_level)
          _pry_.binding_stack.slice!(break_level + 1, _pry_.binding_stack.size)

        else
          max_nest_level = nesting_level - 1
          output.puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
        end
      end

      command "exit-all", "End the current Pry session (popping all bindings) and returning to caller. Accepts optional return value. Aliases: !!@" do
        # clear the binding stack
        _pry_.binding_stack.clear

        # break out of the repl loop
        throw(:breakout, target.eval(arg_string))
      end

      alias_command "!!@", "exit-all"

      create_command "exit" do
        description "Pop the previous binding (does NOT exit program). Type `exit --help` for more information. Aliases: quit"

        banner <<-BANNER
          Usage:   exit [OPTIONS] [--help]
          Aliases: quit

          It can be useful to exit a context with a user-provided value. For
          instance an exit value can be used to determine program flow.

          e.g: `exit "pry this"`
          e.g: `exit`

          https://github.com/pry/pry/wiki/State-navigation#wiki-Exit_with_value
        BANNER

        command_options(
                        :keep_retval => true
                        )

        def process
          if _pry_.binding_stack.one?
            # when breaking out of top-level then behave like `exit-all`
            process_exit_all
          else
            # otherwise just pop a binding and return user supplied value
            process_pop_and_return
          end
        end

        def process_exit_all
          _pry_.binding_stack.clear
          throw(:breakout, target.eval(arg_string))
        end

        def process_pop_and_return
          popped_object = _pry_.binding_stack.pop.eval('self')

          # return a user-specified value if given otherwise return the object
          return target.eval(arg_string) unless arg_string.empty?
          popped_object
        end
      end

      alias_command "quit", "exit"

      command "exit-program", "End the current program. Aliases: quit-program, !!!" do
        Pry.save_history if Pry.config.history.should_save
        Kernel.exit target.eval(arg_string).to_i
      end

      alias_command "quit-program", "exit-program"
      alias_command "!!!", "exit-program"

      command "!pry", "Start a Pry session on current self; this even works mid multi-line expression." do
        target.pry
      end

      create_command "pry-backtrace", "Show the backtrace for the Pry session." do
        banner <<-BANNER
          Usage:   pry-backtrace [OPTIONS] [--help]

          Show the backtrace for the position in the code where Pry was started. This can be used to
          infer the behavior of the program immediately before it entered Pry, just like the backtrace
          property of an exception.

          (NOTE: if you are looking for the backtrace of the most recent exception raised,
          just type: `_ex_.backtrace` instead, see https://github.com/pry/pry/wiki/Special-Locals)

          e.g: pry-backtrace
        BANNER

        def process
          output.puts "\n#{text.bold('Backtrace:')}\n--\n"
          stagger_output _pry_.backtrace.join("\n")
        end
      end

      command "whereami", "Show the code context for the session. (whereami <n> shows <n> extra lines of code around the invocation line. Default: 5)" do |num|
        file = target.eval('__FILE__')
        line_num = target.eval('__LINE__')
        i_num = num ? num.to_i : 5

        if file != Pry.eval_path && (file =~ /(\(.*\))|<.*>/ || file == "" || file == "-e")
          raise CommandError, "Cannot find local context. Did you use `binding.pry`?"
        end

        set_file_and_dir_locals(file)

        method = Pry::Method.from_binding(target)
        method_description = method ? " in #{method.name_with_owner}" : ""
        output.puts "\n#{text.bold('From:')} #{file} @ line #{line_num}#{method_description}:\n\n"

        code = Pry::Code.from_file(file).around(line_num, i_num)
        output.puts code.with_line_numbers.with_marker(line_num)
        output.puts
      end

    end
  end
end
