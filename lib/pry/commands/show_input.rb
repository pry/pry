class Pry
  Pry::Commands.create_command "show-input", "Show the contents of the input buffer for the current multi-line expression." do
    def process
      output.puts Code.new(eval_string).with_line_numbers
    end
  end
end
