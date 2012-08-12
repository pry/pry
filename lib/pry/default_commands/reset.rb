class Pry
  Pry::Commands.command "reset", "Reset the REPL to a clean state." do
    output.puts "Pry reset."
    exec "pry"
  end
end
