class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
        output.puts "Input buffer cleared!"
        opts[:eval_string].clear
      end

      command "amend-line", "Amend the previous line of input. Aliases: %", :interpolate => false do |replacement_line|
        replacement_line = "" if !replacement_line
        input_array = opts[:eval_string].each_line.to_a[0..-2] + [opts[:arg_string] + "\n"]
        opts[:eval_string].replace input_array.join
      end

      alias_command "%", "amend-line", ""

      command "hist", "Show and replay Readline history. Type `hist --help` for more info." do |*args|
        Slop.parse(args) do |opt|
          history = Readline::HISTORY.to_a
          opt.banner "Usage: hist [--replay START..END] [--clear] [--grep PATTERN] [--head N] [--tail N] [--help]\n"

          opt.on :g, :grep, 'A pattern to match against the history.', true do |pattern|
            pattern = Regexp.new opts[:arg_string].split(/ /)[1]
            history.pop

            history.map!.with_index do |element, index|
              if element =~ pattern
                "#{text.blue index}: #{element}"
              end
            end

            stagger_output history.compact.join "\n"
          end

          opt.on :head, 'Display the first N items of history', :optional => true, :as => Integer do |limit|
            unless opt.grep?
              limit ||= 10
              list  = history.first limit
              lines = text.with_line_numbers list.join("\n"), 0
              stagger_output lines
            end
          end

          opt.on :t, :tail, 'Display the last N items of history', :optional => true, :as => Integer do |limit|
            unless opt.grep?
              limit ||= 10
              offset = history.size-limit
              offset = offset < 0 ? 0 : offset

              list  = history.last limit
              lines = text.with_line_numbers list.join("\n"), offset
              stagger_output lines
            end
          end

          opt.on :e, :exclude, 'Exclude pry and system commands from the history.' do
            unless opt.grep?
              history.map!.with_index do |element, index|
                unless command_processor.valid_command? element
                  "#{text.blue index}: #{element}"
                end
              end
              stagger_output history.compact.join "\n"
            end
          end

          opt.on :r, :replay, 'The line (or range of lines) to replay.', true, :as => Range do |range|
            unless opt.grep?
              actions = Array(history[range]).join("\n") + "\n"
              Pry.active_instance.input = StringIO.new(actions)
            end
          end

          opt.on :c, :clear, 'Clear the history' do
            unless opt.grep?
              Readline::HISTORY.clear
              output.puts 'History cleared.'
            end
          end

          opt.on :h, :help, 'Show this message.', :tail => true do
            unless opt.grep?
              output.puts opt.help
            end
          end

          opt.on_empty do
            lines = text.with_line_numbers history.join("\n"), 0
            stagger_output lines
          end
        end
      end

    end

  end
end
