class Pry
  class Command::Cd < Pry::ClassCommand
    match 'cd'
    group 'Context'
    description 'Move into a new context (object or scope).'

    banner <<-'BANNER'
      Usage: cd [OPTIONS] [--help]

      Move into new context (object or scope). As in UNIX shells use `cd ..` to go
      back, `cd /` to return to Pry top-level and `cd -` to toggle between last two
      scopes. Complex syntax (e.g `cd ../@x/@y`) also supported.

      cd @x
      cd ..
      cd /
      cd -

      https://github.com/pry/pry/wiki/State-navigation#wiki-Changing_scope
    BANNER

    def process
      if arg_string.strip == "-"
        _pry_.bstack = []
      else
        stack = ObjectPath.new(arg_string, _pry_.bstack).resolve
        if stack && stack != _pry_.bstack
          _pry_.bstack = stack
        end
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::Cd)
end
