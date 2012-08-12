class Pry
  Pry::Commands.create_command "reset" do
    group 'Context'
    description "Reset the REPL to a clean state."

    def process
      output.puts "Pry reset."
      exec "pry"
    end
  end
end
