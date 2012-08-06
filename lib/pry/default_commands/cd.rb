class Pry
  module DefaultCommands
    Cd = Pry::CommandSet.new do
      create_command "cd" do
        group "Context"
        description "Move into a new context (object or scope)."

        banner <<-BANNER
          Usage: cd [OPTIONS] [--help]

          Move into new context (object or scope). As in unix shells use
          `cd ..` to go back, `cd /` to return to Pry top-level and `cd -`
          to toggle between last two scopes).
          Complex syntax (e.g `cd ../@x/y`) also supported.

          e.g: `cd @x`
          e.g: `cd ..`
          e.g: `cd /`
          e.g: `cd -`

          https://github.com/pry/pry/wiki/State-navigation#wiki-Changing_scope
        BANNER

        def process
          stack, old_stack = context_from_object_path(arg_string, _pry_, state.old_stack||[])
          state.old_stack = old_stack
          _pry_.binding_stack = stack unless stack.nil?
        end

      end
    end
  end

end

