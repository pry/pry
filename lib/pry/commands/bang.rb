class Pry
  Pry::Commands.create_command "!" do
    group 'Editing'
    description "Clear the input buffer. Useful if the parsing process goes " \
      "wrong and you get stuck in the read loop."
    command_options :use_prefix => false

    def process
      output.puts "Input buffer cleared!"
      eval_string.replace("")
    end
  end
end
