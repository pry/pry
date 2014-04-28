class Pry
  # `ObjectPath` implements the resolution of "object paths", which are strings
  # that are similar to filesystem paths but meant for traversing Ruby objects.
  # Examples of valid object paths include:
  #
  #     x
  #     @foo/@bar
  #     "string"/upcase
  #     Pry/Method
  #
  # Object paths are mostly relevant in the context of the `cd` command.
  # @see https://github.com/pry/pry/wiki/State-navigation
  class ObjectPath
    # @param [String] path_string The object path expressed as a string.
    # @param [Array<Binding>] current_stack The current state of the binding
    #   stack.
    # @param [Array<Binding>] old_stack The previous state of the binding
    #   stack, if applicable.
    def initialize(path_string, current_stack, old_stack=[])
      @path_string   = path_string
      @current_stack = current_stack
      @old_stack     = old_stack
    end

    # @return [Array(Array<Binding>, Array<Binding>)] an array
    #   containing two elements, the new binding stack and the old binding
    #   stack.
    def resolve
      # Extract command arguments. Delete blank arguments like " ", but
      # don't delete empty strings like "".
      path      = @path_string.split(/\//).delete_if { |a| a =~ /\A\s+\z/ }
      stack     = @current_stack.dup
      state_old_stack = @old_stack

      # Special case when we only get a single "/", return to root.
      if path.empty?
        state_old_stack = stack.dup unless @old_stack.empty?
        stack = [stack.first]
      end

      path.each_with_index do |context, i|
        begin
          case context.chomp
          when ""
            state_old_stack = stack.dup
            stack = [stack.first]
          when "::"
            state_old_stack = stack.dup
            stack.push(TOPLEVEL_BINDING)
          when "."
            next
          when ".."
            unless stack.size == 1
              # Don't rewrite old_stack if we're in complex expression
              # (e.g.: `cd 1/2/3/../4).
              state_old_stack = stack.dup if path.first == ".."
              stack.pop
            end
          when "-"
            unless @old_stack.empty?
              # Interchange current stack and old stack with each other.
              stack, state_old_stack = state_old_stack, stack
            end
          else
            state_old_stack = stack.dup if i == 0
            stack.push(Pry.binding_for(stack.last.eval(context)))
          end

        rescue RescuableException => e
          # Restore old stack to its initial values.
          state_old_stack = @old_stack

          msg = [
            "Bad object path: #{@path_string}.",
            "Failed trying to resolve: #{context}.",
            e.inspect
          ].join(' ')

          CommandError.new(msg).tap do |err|
            err.set_backtrace e.backtrace
            raise err
          end
        end
      end

      [stack, state_old_stack]
    end
  end
end
