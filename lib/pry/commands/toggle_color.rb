class Pry
  Pry::Commands.command "toggle-color", "Toggle syntax highlighting." do
    Pry.color = !Pry.color
    output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
  end
end
