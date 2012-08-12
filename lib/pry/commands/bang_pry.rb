class Pry
  Pry::Commands.command "!pry", "Start a Pry session on current self; this even works mid multi-line expression." do
    target.pry
  end
end
