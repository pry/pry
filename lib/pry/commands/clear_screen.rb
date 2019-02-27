class Pry
  class Command
    class ClearScreen < Pry::ClassCommand
      match 'clear-screen'
      group 'Input and Output'
      description 'Clear the contents of the screen/window Pry is running in.'

      def process
        if Pry::Helpers::Platform.windows?
          _pry_.config.system.call(_pry_.output, 'cls', _pry_)
        else
          _pry_.config.system.call(_pry_.output, 'clear', _pry_)
        end
      end
      Pry::Commands.add_command(self)
    end
  end
end
