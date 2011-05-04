class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new :input do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
        output.puts "Input buffer cleared!"
        opts[:eval_string].clear
      end

      command "hist", "Show and replay Readline history. Type `hist --help` for more info." do |*args|
        history = Readline::HISTORY.to_a

        Slop.parse(args) do |opt|
          opt.banner "Usage: hist [--replay START..END]\n" \
                     "View and replay history\n" \
                     "e.g hist --replay 2..8"

          opt.on :r, :replay, 'The line (or range of lines) to replay.', true, :as => Range do |range|
            actions = history[range].join("\n") + "\n"
            Pry.active_instance.input = StringIO.new(actions)
          end

          opt.on :c, :clear, 'Clear the history' do
            Readline::HISTORY.clear
            output.puts 'History cleared.'
          end

          opt.on :g, :grep, 'A pattern to match against the history.', true do |pattern|
            history.pop
            matches = history.grep Regexp.new(pattern)
            text = add_line_numbers matches.join("\n"), 0 
            stagger_output text
          end

          opt.on :h, :help, 'Show this message.', :tail => true do
            output.puts opt.help unless opt.g? || opt.r? || opt.c?
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
