class Pry::Command::ClearScreen < Pry::ClassCommand

  match 'clear-screen'
  group 'Input and Output'
  description 'Clear the contents of the screen/window Pry is running in.'

  def process
    if windows?
      _pry_.config.system.call(_pry_.output, 'cls')
    else
      _pry_.config.system.call(_pry_.output, 'clear')
    end
  end
  Pry::Commands.add_command(self)
end
