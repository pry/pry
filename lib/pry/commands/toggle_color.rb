class Pry
  class Command::ToggleColor < Pry::ClassCommand
    match 'toggle-color'
    group 'Misc'
    description 'Toggle syntax highlighting.'

    def process
      Pry.color = !Pry.color
      output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
    end
  end

  Pry::Commands.add_command(Pry::Command::ToggleColor)
end
