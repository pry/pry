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
          path  = arg_string.split(/\//).delete_if { |a| a =~ /\A\s+\z/ }
          stack = _pry_.binding_stack.dup

          # Save current state values for the sake of restoring them them later
          # (for example, when an exception raised).
          old_binding = state.old_binding
          append      = state.append

          # Special case when we only get a single "/", return to root.
          if path.empty?
            set_old_binding(stack.last, true) if old_binding
            stack = [stack.first]
          else
            # Prevent setting old_binding to itself when there is no more
            # elements in stack.
            set_old_binding(stack.last, false) unless stack.size == 1
          end

          path.each do |context|
            begin
              case context.chomp
              when ""
                set_old_binding(stack.last, true)
                stack = [stack.first]
              when "::"
                stack.push(TOPLEVEL_BINDING)
              when "."
                next
              when ".."
                unless stack.size == 1
                  if path.first == ".."
                    set_old_binding(stack.pop, true)
                  else
                    set_old_binding(stack.last, false) unless path.length > 1
                    stack.pop
                  end
                end
              when "-"
                if state.old_binding
                  toggle_old_binding(stack, old_binding, append)
                end
              else
                unless path.length > 1
                  set_old_binding(stack.last, false)
                end
                stack.push(Pry.binding_for(stack.last.eval(context)))
              end

            rescue RescuableException => e
              set_old_binding(old_binding, append) # Restore previous values.

              output.puts "Bad object path: #{arg_string.chomp}. Failed trying to resolve: #{context}"
              output.puts e.inspect
              return
            end
          end

          _pry_.binding_stack = stack
        end

        private

        # Toggle old binding value by either appending it to the current stack
        # (when `append` is `true`) or setting the new one (when `append` is
        # `false`).
        #
        # @param [Array<Binding>] stack The current stack of bindings.
        # @param [Binding] old_binding The old binding.
        # @param [Boolean] append The adjunction flag.
        #
        # @return [Binding] The new old binding.
        def toggle_old_binding(stack, old_binding, append)
          if append
            stack.push(old_binding)
            old_binding = stack[-2]
          else
            stack.pop.tap do |ob|
              if stack.size > 1
                # Keep hurtling stuff out until we reach previous old binding
                # or the last element in the stack (just to ensure that we are
                # not in the endless loop).
                stack.pop until stack.last == old_binding || stack.size == 1
              end
              old_binding = ob
            end
          end
          append = !append

          set_old_binding(old_binding, append)

          old_binding
        end

        # Set new old binding and adjunction flag.
        #
        # @param [Binding] binding The old binding.
        # @param [Boolean] append The adjunction flag.
        #
        # @return [void]
        def set_old_binding(binding, append)
          state.old_binding = binding
          state.append = append
        end

      end
    end
  end
end
