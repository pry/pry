class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new do

      create_command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop.", :use_prefix => false do
        def process
          output.puts "Input buffer cleared!"
          eval_string.replace("")
        end
      end

      create_command "show-input", "Show the contents of the input buffer for the current multi-line expression." do
        def process
          output.puts Code.new(eval_string).with_line_numbers
        end
      end

      create_command(/amend-line(?: (-?\d+)(?:\.\.(-?\d+))?)?/) do
        description "Amend a line of input in multi-line mode. Type `amend-line --help` for more information. Aliases %"
        command_options :interpolate => false, :listing => "amend-line"

        banner <<-'BANNER'
          Amend a line of input in multi-line mode. `amend-line N`, where the N in `amend-line N` represents line to replace.

          Can also specify a range of lines using `amend-line N..M` syntax. Passing '!' as replacement content deletes the line(s) instead. Aliases: %N
          e.g amend-line 1 puts 'hello world! # replace line 1'
          e.g amend-line 1..4 !               # delete lines 1..4
          e.g amend-line 3 >puts 'goodbye'    # insert before line 3
          e.g amend-line puts 'hello again'   # no line number modifies immediately preceding line
        BANNER

        def process
          start_line_number, end_line_number, replacement_line = *args

          if eval_string.empty?
            raise CommandError, "No input to amend."
          end

          replacement_line = "" if !replacement_line
          input_array = eval_string.each_line.to_a

          end_line_number = start_line_number.to_i if !end_line_number
          line_range = start_line_number ? (one_index_number(start_line_number.to_i)..one_index_number(end_line_number.to_i))  : input_array.size - 1

          # delete selected lines if replacement line is '!'
          if arg_string == "!"
            input_array.slice!(line_range)
          elsif arg_string.start_with?(">")
            insert_slot = Array(line_range).first
            input_array.insert(insert_slot, arg_string[1..-1] + "\n")
          else
            input_array[line_range] = arg_string + "\n"
          end
          eval_string.replace input_array.join
          run "show-input"
        end
      end

      alias_command(/%.?(-?\d+)?(?:\.\.(-?\d+))?/, "amend-line")

      create_command "play" do
        description "Play back a string variable or a method or a file as input. Type `play --help` for more information."

        banner <<-BANNER
          Usage: play [OPTIONS] [--help]

          The play command enables you to replay code from files and methods as
          if they were entered directly in the Pry REPL. Default action (no
          options) is to play the provided string variable

          e.g: `play _in_[20] --lines 1..3`
          e.g: `play -m Pry#repl --lines 1..-1`
          e.g: `play -f Rakefile --lines 5`

          https://github.com/pry/pry/wiki/User-Input#wiki-Play
        BANNER

        def options(opt)
          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true
          opt.on :f, "file", 'The file to replay in context.', true
          opt.on :o, "open", 'When used with the -m switch, it plays the entire method except the last line, leaving the method definition "open". `amend-line` can then be used to modify the method.'
        end

        def process
          if opts.present?(:method)
            process_method
          elsif opts.present?(:file)
            process_file
          else
            process_input
          end

          run "show-input" unless _pry_.complete_expression?(eval_string)
        end

        def process_method
          meth_name = opts[:m]
          meth = get_method_or_raise(meth_name, target, {}, :omit_help)
          return unless meth.source

          range = opts.present?(:lines) ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.present?(:open)

          eval_string << Array(meth.source.each_line.to_a[range]).join
        end

        def process_file
          file_name = File.expand_path(opts[:f])

          if !File.exists?(file_name)
            raise CommandError, "No such file: #{opts[:f]}"
          end

          text_array = File.readlines(file_name)
          range = opts.present?(:lines) ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.present?(:open)

          eval_string << Array(text_array[range]).join
        end

        def process_input
          if !args.first
            raise CommandError, "No input to play command."
          end

          code = target.eval(args.first)

          range = opts.present?(:lines) ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.present?(:open)

          eval_string << Array(code.each_line.to_a[range]).join
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
          _pry_.input_stack << _pry_.input
          _pry_.input = StringIO.new(@history.to_s)
        end
      end

      alias_command "history", "hist"
    end
  end
end
