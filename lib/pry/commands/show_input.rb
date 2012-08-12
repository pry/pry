class Pry
  Pry::Commands.create_command "show-input" do
    group 'Editing'
    description "Show the contents of the input buffer for the current multi-line expression."

    def process
      output.puts Code.new(eval_string).with_line_numbers
    end
  end
end
