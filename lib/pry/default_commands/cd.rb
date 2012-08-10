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
          # Extract command arguments. Delete blank arguments like " ", but
          # don't delete empty strings like "".
          path      = arg_string.split(/\//).delete_if { |a| a =~ /\A\s+\z/ }
          stack     = _pry_.binding_stack.dup
          old_stack = state.old_stack || []

          # Special case when we only get a single "/", return to root.
          if path.empty?
            state.old_stack = stack.dup unless old_stack.empty?
            stack = [stack.first]
          end

          path.each_with_index do |context, i|
            begin
              case context.chomp
              when ""
                state.old_stack = stack.dup
                stack = [stack.first]
              when "::"
                state.old_stack = stack.dup
                stack.push(TOPLEVEL_BINDING)
              when "."
                next
              when ".."
                unless stack.size == 1
                  # Don't rewrite old_stack if we're in complex expression
                  # (e.g.: `cd 1/2/3/../4).
                  state.old_stack = stack.dup if path.first == ".."
                  stack.pop
                end
              when "-"
                unless old_stack.empty?
                  # Interchange current stack and old stack with each other.
                  stack, state.old_stack = state.old_stack, stack
                end
              else
                state.old_stack = stack.dup if i == 0
                stack.push(Pry.binding_for(stack.last.eval(context)))
              end

            rescue RescuableException => e
              # Restore old stack to its initial values.
              state.old_stack = old_stack

              output.puts "Bad object path: #{arg_string.chomp}. Failed trying to resolve: #{context}"
              output.puts e.inspect
              return
            end
          end

          _pry_.binding_stack = stack
        end

      end
    end
  end
end
