class Pry
  class Command::Cd < Pry::ClassCommand
    match 'cd'
    group 'Context'
    description 'change position in the binding stack'

    banner <<-'BANNER'
      Usage: cd [OPTIONS] [--help]

      Move into new context (object or scope). As in UNIX shells use `cd ..` to go
      back, `cd /` to return to Pry top-level and `cd -` to toggle between last two
      scopes. Complex syntax (e.g `cd ../@x/@y`) also supported.

      cd @x/@y/@z
      cd @x/@y/@z/..
      cd @x/@y
      cd -

    BANNER

    def process(str)
      _pry_.bstack.traverse_via(str)
    end
  end

  Pry::Commands.add_command(Pry::Command::Cd)
end
