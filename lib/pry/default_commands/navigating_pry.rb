class Pry
  module DefaultCommands

    NavigatingPry = Pry::CommandSet.new do
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
        description "Pop the previous binding (does NOT exit program). Aliases: quit"

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

      create_command "cd" do
        description "Move into a new context (object or scope)."

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

      create_command "hist", "Show and replay Readline history. Aliases: history" do
        banner <<-USAGE
          Usage: hist
                 hist --head N
                 hist --tail N
                 hist --show START..END
                 hist --grep PATTERN
                 hist --clear
                 hist --replay START..END
                 hist --save [START..END] FILE
        USAGE

        def options(opt)
          opt.on :H, :head, "Display the first N items.", :optional => true, :as => Integer
          opt.on :T, :tail, "Display the last N items.", :optional => true, :as => Integer
          opt.on :s, :show, "Show the given range of lines.", :optional => true, :as => Range
          opt.on :G, :grep, "Show lines matching the given pattern.", true, :as => String
          opt.on :c, :clear, "Clear the current session's history."
          opt.on :r, :replay, "Replay a line or range of lines.", true, :as => Range
          opt.on     :save, "Save history to a file.", true, :as => Range

          opt.on :e, :'exclude-pry', "Exclude Pry commands from the history."
          opt.on :n, :'no-numbers', "Omit line numbers."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          @history = Pry::Code(Pry.history.to_a)

          @history = case
            when opts.present?(:head)
              @history.between(1, opts[:head] || 10)
            when opts.present?(:tail)
              @history.between(-(opts[:tail] || 10), -1)
            when opts.present?(:show)
              @history.between(opts[:show])
            else
              @history
            end

          if opts.present?(:grep)
            @history = @history.grep(opts[:grep])
          end

          if opts.present?(:'exclude-pry')
            @history = @history.select { |l, ln| !command_set.valid_command?(l) }
          end

          if opts.present?(:save)
            process_save
          elsif opts.present?(:clear)
            process_clear
          elsif opts.present?(:replay)
            process_replay
          else
            process_display
          end
        end

        def process_display
          unless opts.present?(:'no-numbers')
            @history = @history.with_line_numbers
          end

          render_output(@history, opts)
        end

        def process_save
          case opts[:save]
          when Range
            @history = @history.between(opts[:save])

            unless args.first
              raise CommandError, "Must provide a file name."
            end

            file_name = File.expand_path(args.first)
          when String
            file_name = File.expand_path(opts[:save])
          end

          output.puts "Saving history in #{file_name}..."

          File.open(file_name, 'w') { |f| f.write(@history.to_s) }

          output.puts "History saved."
        end

        def process_clear
          Pry.history.clear
          output.puts "History cleared."
        end

        def process_replay
          @history = @history.between(opts[:r])

          _pry_.input_stack.push _pry_.input
          _pry_.input = StringIO.new(@history.raw)
          # eval_string << "#{@history.raw}\n"
          # run "show-input" unless _pry_.complete_expression?(eval_string)
        end
      end

      alias_command "history", "hist"

    end
  end
end

