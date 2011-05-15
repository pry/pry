class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do

      command "show-eval", "Show the current eval_string" do
        output.puts opts[:eval_string]
      end

      command "play-string", "Play a string as input" do
        Pry.active_instance.input = StringIO.new(opts[:arg_string])
      end

    end
  end
end
