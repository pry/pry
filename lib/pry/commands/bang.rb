class Pry
  Pry::Commands.create_command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop.", :use_prefix => false do
    def process
      output.puts "Input buffer cleared!"
      eval_string.replace("")
    end
  end
end
