class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new :input do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
        output.puts "Input buffer cleared!"
        opts[:eval_string].clear
      end

      command "amend-line", "Amend the previous line of input. Aliases: %" do |replacement_line|
        replacement_line = "" if !replacement_line
        input_array = opts[:eval_string].each_line.to_a[0..-2] + [opts[:ni_arg_string] + "\n"]
        opts[:eval_string].replace input_array.join("\n")
      end

      alias_command "%", "amend-line", ""

      command "hist", "Show and replay Readline history. Type `hist --help` for more info." do |*args|
        history = Readline::HISTORY.to_a

        Slop.parse(args) do |opt|
          opt.banner "Usage: hist [--replay START..END] [--clear] [--grep PATTERN] [--help]\n"

          opt.on :g, :grep, 'A pattern to match against the history.', true do |pattern|
            pattern = Regexp.new pattern
            history.pop

            history.each_with_index do |element, index|
              if element =~ pattern
                output.puts "#{colorize index}: #{element}"
              end
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
            text = add_line_numbers history.join("\n"), 0
            stagger_output text
          end
        end
      end

    end

  end
end
