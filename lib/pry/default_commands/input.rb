class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop.", :use_prefix => false do
        output.puts "Input buffer cleared!"
        eval_string.replace("")
      end

      command "show-input", "Show the contents of the input buffer for the current multi-line expression." do
        render_output(false, 1, Pry.color ? CodeRay.scan(eval_string, :ruby).term : eval_string)
      end

      command(/amend-line(?: (-?\d+)(?:\.\.(-?\d+))?)?/, "Amend a line of input in multi-line mode. Type `amend-line --help` for more information. Aliases %",
              :interpolate => false, :listing => "amend-line")  do |*args|
        start_line_number, end_line_number, replacement_line = *args

        opts = Slop.parse!(args.compact) do |opt|
          opt.banner unindent <<-USAGE
            Amend a line of input in multi-line mode. `amend-line N`, where the N in `amend-line N` represents line to replace.

            Can also specify a range of lines using `amend-line N..M` syntax. Passing '!' as replacement content deletes the line(s) instead. Aliases: %N
            e.g amend-line 1 puts 'hello world! # replace line 1'
            e.g amend-line 1..4 !               # delete lines 1..4
            e.g amend-line 3 >puts 'goodbye'    # insert before line 3
            e.g amend-line puts 'hello again'   # no line number modifies immediately preceding line
          USAGE

          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.h?
        next output.puts "No input to amend." if eval_string.empty?

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

      alias_command(/%.?(-?\d+)?(?:\.\.(-?\d+))?/, /amend-line(?: (-?\d+)(?:\.\.(-?\d+))?)?/, "")

      command "play", "Play back a string variable or a method or a file as input. Type `play --help` for more information." do |*args|
        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: play [OPTIONS] [--help]
            Default action (no options) is to play the provided string variable
            e.g `play _in_[20] --lines 1..3`
            e.g `play -m Pry#repl --lines 1..-1`
            e.g `play -f Rakefile --lines 5`
          USAGE

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true
          opt.on :f, "file", 'The file to replay in context.', true
          opt.on :o, "open", 'When used with the -m switch, it plays the entire method except the last line, leaving the method definition "open". `amend-line` can then be used to modify the method.'
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        if opts.m?
          meth_name = opts[:m]
          if (meth = get_method_object(meth_name, target, {})).nil?
            output.puts "Invalid method name: #{meth_name}."
            next
          end
          code, _ = code_and_code_type_for(meth)
          next if !code

          range = opts.l? ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.o?

          eval_string.replace(Array(code.each_line.to_a[range]).join)
          run "show-input" if opts.o?
        elsif opts.f?
          file_name = File.expand_path(opts[:f])
          next output.puts "No such file: #{opts[:f]}" if !File.exists?(file_name)
          text_array = File.readlines(file_name)
          range = opts.l? ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.o?

          _pry_.input = StringIO.new(Array(text_array[range]).join)
        else
          next output.puts "Error: no input to play command" if !args.first
          code = target.eval(args.first)

          range = opts.l? ? one_index_range_or_number(opts[:l]) : (0..-1)
          range = (0..-2) if opts.o?

          eval_string << Array(code.each_line.to_a[range]).join
        end
      end

      command "hist", "Show and replay Readline history. Type `hist --help` for more info. Aliases: history" do |*args|
        # exclude the current command from history.
        history = Pry.history.to_a[0..-2]

        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: hist [--replay START..END] [--clear] [--grep PATTERN] [--head N] [--tail N] [--help] [--save [START..END] file.txt]\n"

          opt.on :g, :grep, 'A pattern to match against the history.', true do |pattern|
            pattern = Regexp.new arg_string.strip.split(/ /, 2).last.strip
            history.pop

            history.map!.with_index do |element, index|
              if element =~ pattern
                "#{text.blue index}: #{element}"
              end
            end

            stagger_output history.compact.join "\n"
          end

          opt.on :head, 'Display the first N items of history',
                 :optional => true,
                 :as       => Integer,
                 :unless   => :grep do |limit|

            limit ||= 10
            list  = history.first limit
            lines = text.with_line_numbers list.join("\n"), 0
            stagger_output lines
          end

          opt.on :t, :tail, 'Display the last N items of history',
                     :optional => true,
                     :as       => Integer,
                     :unless   => :grep do |limit|

            limit ||= 10
            offset = history.size - limit
            offset = offset < 0 ? 0 : offset

            list  = history.last limit
            lines = text.with_line_numbers list.join("\n"), offset
            stagger_output lines
          end

          opt.on :s, :show, 'Show the history corresponding to the history line (or range of lines).',
                 true,
                 :as     => Range,
                 :unless => :grep do |range|

            start_line = range.is_a?(Range) ? range.first : range
            lines = text.with_line_numbers Array(history[range]).join("\n"), start_line
            stagger_output lines
          end

          opt.on :e, :exclude, 'Exclude pry commands from the history.', :unless => :grep do
            history.map!.with_index do |element, index|
              unless command_processor.valid_command? element
                "#{text.blue index}: #{element}"
              end
            end
            stagger_output history.compact.join "\n"
          end

          opt.on :r, :replay, 'The line (or range of lines) to replay.',
                 true,
                 :as     => Range,
                 :unless => :grep do |range|
            actions = Array(history[range]).join("\n") + "\n"
            _pry_.input = StringIO.new(actions)
          end

          opt.on "save", "Save history to a file. --save [start..end] output.txt. Pry commands are excluded from saved history.", true, :as => Range

          opt.on :c, :clear, 'Clear the history', :unless => :grep do
            Pry.history.clear
            output.puts 'History cleared.'
          end

          opt.on :h, :help, 'Show this message.', :tail => true, :unless => :grep do
            output.puts opt.help
          end

          opt.on_empty do
            lines = text.with_line_numbers history.join("\n"), 0
            stagger_output lines
          end
        end

        # FIXME: hack to save history (this must be refactored)
        if opts["save"]
          file_name = nil
          hist_array = nil

          case opts["save"]
          when Range
            hist_array = Array(history[opts["save"]])
            next output.puts "Must provide a file name." if !args.first
            file_name = File.expand_path(args.first)
          when String
            hist_array = history
            file_name =  File.expand_path(opts["save"])
          end

          output.puts "Saving history in #{file_name} ..."
          # exclude pry commands
          hist_array.reject! do |element|
            command_processor.valid_command?(element)
          end

          File.open(file_name, 'w') do |f|
            f.write hist_array.join("\n")
          end

          output.puts "... history saved."
        end

      end

      alias_command "history", "hist", ""

      helpers do
        def one_index_number(line_number)
          if line_number > 0
            line_number - 1
          elsif line_number < 0
            line_number
          else
            line_number
          end
        end

        def one_index_range(range)
          Range.new(one_index_number(range.begin), one_index_number(range.end))
        end

        def one_index_range_or_number(range_or_number)
          case range_or_number
          when Range
            one_index_range(range_or_number)
          else
            one_index_number(range_or_number)
          end
        end

      end

    end

  end
end
