class Pry
  class Hooks

    def initialize
      @hooks = {}
    end

    # Add a new hook to be executed for the `name` even.
    # @param [Symbol] name The name of the event.
    # @param [Symbol] hook_function_name The name of the hook.
    # @param [#call] callable The callable.
    # @yield The block to use as the callable (if `callable` parameter not provided)
    def add_hook(name, hook_function_name, callable=nil, &block)
      @hooks[name] ||= {}

      if block
        @hooks[name][hook_function_name] = block
      elsif callable
        @hooks[name][hook_function_name] = callable
      else
        raise ArgumentError, "Must provide a block or callable."
      end

      self
    end

    # Execute the list of hooks for the `name` event.
    # @param [Symbol] name The name of the event.
    # @param [Array] args The arguments to pass to each hook function.
    # @return [Hash] The return values for each of the hook functions.
    def exec_hook(name, *args, &block)
      @hooks[name] ||= {}
      Hash[@hooks[name].each.map { |k, v| [k, v.call(*args, &block)] }]
    end

    # Return the number of hook functions registered for the `name` event.
    # @param [Symbol] name The name of the event.
    # @return [Fixnum] The number of hook functions for the `name` event.
    def hook_count(name)
      @hooks[name] ||= {}
      @hooks[name].size
    end

    # Return the hash of hook names / hook functions for a
    # given event.
    # @param [Symbol] name The name of the event.
    # @return [Hash]
    def get_hook(name, hook_function_name)
      @hooks[name] ||= {}
      @hooks[name][hook_function_name]
    end

    # Delete a hook for an event.
    # @param [Symbol] name The name of the event.
    # @param [Symbol] hook_function_name The name of the hook.
    #   to delete.
    # @return [#call] The deleted hook.
    def delete_hook(name, hook_function_name)
      @hooks[name] ||= {}
      @hooks[name].delete(hook_function_name)
    end

    # Clear all hooks functions for a given event.
    # @param [String] name The name of the event.
    def clear(name)
      @hooks[name] = {}
    end

  end
end
