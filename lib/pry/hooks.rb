class Pry
  class Hooks

    def initialize
      @hooks = {}
    end

    # Add a new hook to be executed for the `name` even.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol] hook_name The name of the hook.
    # @param [#call] callable The callable.
    # @yield The block to use as the callable (if `callable` parameter not provided)
    def add_hook(event_name, hook_name, callable=nil, &block)
      @hooks[event_name] ||= []

      # do not allow duplicates
      raise ArgumentError, "Hook with name '#{hook_name}' already defined!" if hook_exists?(event_name, hook_name)

      if block
        @hooks[event_name] << [hook_name, block]
      elsif callable
        @hooks[event_name] << [hook_name, callable]
      else
        raise ArgumentError, "Must provide a block or callable."
      end

      self
    end

    # Execute the list of hooks for the `event_name` event.
    # @param [Symbol] event_name The name of the event.
    # @param [Array] args The arguments to pass to each hook function.
    # @return [Object] The return value of the last executed hook.
    def exec_hook(event_name, *args, &block)
      @hooks[event_name] ||= []

      # silence warnings to get rid of 1.8's "warning: multiple values
      # for a block parameter" warnings
      Pry::Helpers::BaseHelpers.silence_warnings do
        @hooks[event_name].map { |hook_name, callable| callable.call(*args, &block) }.last
      end
    end

    # Return the number of hook functions registered for the `event_name` event.
    # @param [Symbol] event_name The name of the event.
    # @return [Fixnum] The number of hook functions for `event_name`.
    def hook_count(event_name)
      @hooks[event_name] ||= []
      @hooks[event_name].size
    end

    # Return a specific hook for a given event.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol[ hook_name The name of the hook
    # @return [#call] The requested hook.
    def get_hook(event_name, hook_name)
      @hooks[event_name] ||= []
      hook = @hooks[event_name].find { |current_hook_name, callable| current_hook_name == hook_name }
      hook.last if hook
    end

    # Return the hash of hook names / hook functions for a
    # given event. (Note that modifying the returned hash does not
    # alter the hooks, use add_hook/delete_hook for that).
    # @param [Symbol] event_name The name of the event.
    # @return [Hash] The hash of hook names / hook functions.
    def get_hooks(event_name)
      @hooks[event_name] ||= []
      Hash[@hooks[event_name]]
    end

    # Delete a hook for an event.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol] hook_name The name of the hook.
    #   to delete.
    # @return [#call] The deleted hook.
    def delete_hook(event_name, hook_name)
      @hooks[event_name] ||= []
      deleted_callable = nil

      @hooks[event_name].delete_if do |current_hook_name, callable|
        if current_hook_name == hook_name
          deleted_callable = callable
          true
        else
          false
        end
      end
      deleted_callable
    end

    # Clear all hooks functions for a given event.
    # @param [String] event_name The name of the event.
    def delete_hooks(event_name)
      @hooks[event_name] = []
    end

    alias_method :clear, :delete_hooks

    # @param [Symbol] event_name Name of the event.
    # @param [Symbol] hook_name Name of the hook.
    # @return [Boolean] Whether the hook by the name `hook_name`
    #   is defined for the event.
    def hook_exists?(event_name, hook_name)
      !!@hooks[event_name].find { |name, _| name == hook_name }
    end
    private :hook_exists?

  end
end
