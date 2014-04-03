class Pry
  class Command::ToggleColor < Pry::ClassCommand
    match 'toggle-color'
    group 'Misc'
    description 'Toggle syntax highlighting.'

    banner <<-'BANNER'
      Usage: toggle-color

      Toggle syntax highlighting.
    BANNER

    def process
      _pry_.color = !_pry_.color
      output.puts "Syntax highlighting #{_pry_.color ? "on" : "off"}"
    end
    Pry::Commands.add_command(self)
  end
end
