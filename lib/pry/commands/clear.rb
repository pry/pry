class Pry
  class Command::Clear < Pry::ClassCommand
    match 'clear'
    group 'Input and Output'
    description 'Clears the current screen'

    banner <<-'BANNER'
      Usage: clear

      Clears the screen, ignores any parameters that may be present.
    BANNER

    def process
      _pry_.config.system.call(output, 'clear', _pry_)
    end
  end

  Pry::Commands.add_command(Pry::Command::Clear)
end
