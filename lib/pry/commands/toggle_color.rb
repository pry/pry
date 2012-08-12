class Pry
  Pry::Commands.create_command "toggle-color" do
    group 'Misc'
    description "Toggle syntax highlighting."

    def process
      Pry.color = !Pry.color
      output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
    end
  end
end
