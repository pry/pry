class Pry
  module DefaultCommands

    Input = Pry::CommandSet.new :input do

      command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
        output.puts "Input buffer cleared!"
        opts[:eval_string].clear
      end

      command "hist", "Show and replay Readline history. When given no args history is displayed.\nType `hist --help` for more info." do |*args|
        hist_array = Readline::HISTORY.to_a

        if args.empty?
          text = add_line_numbers(hist_array.join("\n"), 0)
          stagger_output(text)
          next
        end

        opts = Slop.parse(args) do |opt|
          opt.banner "Usage: hist [--replay START..END]\nView and replay history\nWhen given no args, history is displayed.\ne.g hist --replay 2..8"
          opt.on :r, :replay, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :h, :help, 'Show this message.', :tail => true do
            output.puts opt.help
          end
        end

        next if opts.h?

        actions = Array(hist_array[opts[:replay]]).join("\n") + "\n"
        Pry.active_instance.input = StringIO.new(actions)
      end


    end

  end
end
