class Pry

  # Implements a hooks system for Pry. A hook is a callable that is
  # associated with an event. A number of events are currently
  # provided by Pry, these include: `:when_started`, `:before_session`, `:after_session`.
  # A hook must have a name, and is connected with an event by the
  # `Pry::Hooks#add_hook` method.
  # @example Adding a hook for the `:before_session` event.
  #   Pry.config.hooks.add_hook(:before_session, :say_hi) do
  #     puts "hello"
  #   end
  class Hooks

    # Converts a hash to a `Pry::Hooks` instance. All hooks defined
    # this way are anonymous. This functionality is primarily to
    # provide backwards-compatibility with the old hash-based hook
    # system in Pry versions < 0.9.8
    # @param [Hash] hash The hash to convert to `Pry::Hooks`.
    # @return [Pry::Hooks] The resulting `Pry::Hooks` instance.
    def self.from_hash(hash)
      return hash if hash.instance_of?(self)
      instance = new
      hash.each do |k, v|
        instance.add_hook(k, nil, v)
      end
      instance
    end

    def initialize
      @hooks = {}
    end

    # Ensure that duplicates have their @hooks object
    def initialize_copy(orig)
      hooks_dup = @hooks.dup
      @hooks.each do |k, v|
        hooks_dup[k] = v.dup
      end

      @hooks = hooks_dup
    end

    def hooks
      @hooks
    end
    protected :hooks

    def errors
      @errors ||= []
    end

    # Destructively merge the contents of two `Pry:Hooks` instances.
    # @param [Pry::Hooks] other The `Pry::Hooks` instance to merge
    # @return [Pry:Hooks] Returns the receiver.
    # @example
    #   hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   Pry::Hooks.new.merge!(hooks)
    def merge!(other)
      @hooks.merge!(other.dup.hooks) do |key, v1, v2|
        merge_arrays(v1, v2)
      end

      self
    end

    def merge_arrays(array1, array2)
      uniq_keeping_last(array1 + array2, &:first)
    end
    private :merge_arrays

    def uniq_keeping_last(input, &block)
      hash, output = {}, []
      input.reverse.each{ |i| hash[block[i]] ||= (output.unshift i) }
      output
    end
    private :uniq_keeping_last

    # Return a new `Pry::Hooks` instance containing a merge of the contents of two `Pry:Hooks` instances,
    # @param [Pry::Hooks] other The `Pry::Hooks` instance to merge
    # @return [Pry::Hooks] The new hash.
    # @example
    #   hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   Pry::Hooks.new.merge(hooks)
    def merge(other)
      self.dup.tap do |v|
        v.merge!(other)
      end
    end

    # Add a new hook to be executed for the `name` even.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol] hook_name The name of the hook.
    # @param [#call] callable The callable.
    # @yield The block to use as the callable (if `callable` parameter not provided)
    # @return [Pry:Hooks] Returns the receiver.
    # @example
    #   Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    def add_hook(event_name, hook_name, callable=nil, &block)
      @hooks[event_name] ||= []

      # do not allow duplicates, but allow multiple `nil` hooks
      # (anonymous hooks)
      if hook_exists?(event_name, hook_name) && !hook_name.nil?
        raise ArgumentError, "Hook with name '#{hook_name}' already defined!"
      end

      if !block && !callable
        raise ArgumentError, "Must provide a block or callable."
      end

      # ensure we only have one anonymous hook
      @hooks[event_name].delete_if { |h, k| h.nil? } if hook_name.nil?

      if block
        @hooks[event_name] << [hook_name, block]
      elsif callable
        @hooks[event_name] << [hook_name, callable]
      end

      self
    end

    # Execute the list of hooks for the `event_name` event.
    # @param [Symbol] event_name The name of the event.
    # @param [Array] args The arguments to pass to each hook function.
    # @return [Object] The return value of the last executed hook.
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.exec_hook(:before_session) #=> OUTPUT: "hi!"
    def exec_hook(event_name, *args, &block)
      @hooks[event_name] ||= []

      @hooks[event_name].map do |hook_name, callable|
        begin
          callable.call(*args, &block)
        rescue RescuableException => e
          errors << e
          e
        end
      end.last
    end

    # Return the number of hook functions registered for the `event_name` event.
    # @param [Symbol] event_name The name of the event.
    # @return [Fixnum] The number of hook functions for `event_name`.
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.count(:before_session) #=> 1
    def hook_count(event_name)
      @hooks[event_name] ||= []
      @hooks[event_name].size
    end

    # Return a specific hook for a given event.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol] hook_name The name of the hook
    # @return [#call] The requested hook.
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.get_hook(:before_session, :say_hi).call #=> "hi!"
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
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.get_hooks(:before_session) #=> {:say_hi=>#<Proc:0x00000101645e18@(pry):9>}
    def get_hooks(event_name)
      @hooks[event_name] ||= []
      Hash[@hooks[event_name]]
    end

    # Delete a hook for an event.
    # @param [Symbol] event_name The name of the event.
    # @param [Symbol] hook_name The name of the hook.
    #   to delete.
    # @return [#call] The deleted hook.
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.delete_hook(:before_session, :say_hi)
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
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.delete_hook(:before_session)
    def delete_hooks(event_name)
      @hooks[event_name] = []
    end

    alias_method :clear, :delete_hooks

    # Remove all events and hooks, clearing out the Pry::Hooks
    # instance completely.
    # @example
    #   my_hooks = Pry::Hooks.new.add_hook(:before_session, :say_hi) { puts "hi!" }
    #   my_hooks.clear_all
    def clear_all
      @hooks = {}
    end

    # @param [Symbol] event_name Name of the event.
    # @param [Symbol] hook_name Name of the hook.
    # @return [Boolean] Whether the hook by the name `hook_name`
    def hook_exists?(event_name, hook_name)
      !!(@hooks[event_name] && @hooks[event_name].find { |name, _| name == hook_name })
    end
  end
end
