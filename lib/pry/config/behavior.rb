class Pry
  class Config < Pry::BasicObject
    #
    # {Pry::Config::Behavior} is a module who can be included by classes who
    # wish to behave similar to an OpenStruct object:
    #
    # ```ruby
    # class Store
    #   include Pry::Config::Behavior
    # end
    # store = Store.from_hash(number: 300)
    # store.number    # => 300
    # store[:number]  # => 300
    # store['number'] # => 300
    # ```
    #
    # Classes who include {Pry::Config::Behavior} can be linked to each other
    # to provide a default in case a key does not exist locally:
    #
    # ```ruby
    # class Store
    #   include Pry::Config::Behavior
    # end
    # store = Store.from_hash({}, Store.from_hash(greeting: 'hello'))
    # store.greeting # => 'hello'
    # ```
    #
    # When an object is read from a default like in the example above, a copy
    # of the object is created to avoid a mutation changing its value:
    #
    # ```ruby
    # default = Store.from_hash(greeting: 'hello')
    # store = Store.from_hash({}, default)
    # store.greeting # => 'hello'
    # default.greeting.sub! 'hello', 'goodbye'
    # store.greeting # => 'hello'
    # ```
    #
    module Behavior
      ASSIGNMENT = "=".freeze

      NODUP = [
        TrueClass, FalseClass, NilClass, Symbol, Numeric, Module, Proc,
        Pry::Prompt, Pry::Config::Lazy
      ].freeze

      INSPECT_REGEXP = /#{Regexp.escape "default=#<"}/
      ReservedKeyError = Class.new(RuntimeError)

      #
      # The instance methods of this module are available as singleton methods
      # on classes who include {Pry::Config::Behavior}. The methods can be used
      # to initialize a {Pry::Config::Behavior} object from a Hash object.
      #
      # @example
      #   class Store
      #     include Pry::Config::Behavior
      #   end
      #   obj1 = Store.assign(foo: 1, bar: 2)
      #   obj2 = Store.from_hash(foo: 1, bar: 2)
      #   [obj1.class, obj2.class] # => [Store, Store]
      #
      module Builder
        #
        # @example
        #   c = Pry::Config.assign(foo: {bar: {baz: 42}})
        #   c.class # => Pry::Config
        #   c.foo.class # => Hash
        #
        # @param
        #   (see #from_hash)
        #
        # @return [Pry::Config::Behavior]
        #   An instance of an object that has included Pry::Config::Behavior.
        #   `attributes` is not visited using recursion.
        #
        def assign(attributes, default = nil)
          new(default).tap do |behavior|
            behavior.merge!(attributes)
          end
        end

        #
        # @example
        #   c = Pry::Config.from_hash(foo: {bar: {baz: 42}})
        #   c.foo.bar.class # => Pry::Config
        #   c.foo.bar.baz   # => 42
        #
        # @param [Hash] attributes
        #
        # @param [Pry::Config::Behavior, nil] default
        #   A default, or nil for none.
        #
        # @return [Pry::Config::Behavior]
        #   An instance of an object that has included Pry::Config::Behavior.
        #   `attributes` is visited using recursion.
        #
        def from_hash(attributes, default = nil)
          new(default).tap do |config|
            attributes.each do |key,value|
              config[key] = if Hash === value
                              from_hash(value)
                            elsif Array === value
                              value.map { |v| Hash === v ? from_hash(v) : v }
                            else
                              value
                            end
            end
          end
        end
      end

      def self.included(klass)
        klass.extend(Builder)
      end

      #
      # @example
      #   class Store
      #     include Pry::Config::Behavior
      #   end
      #   c = Store.new(Pry.config)
      #   c.input # => Readline
      #
      # @param [Pry::Config::Behavior, nil] default
      #   A default to query when a key is not found in self, or nil for none.
      #
      #
      def initialize(default = Pry.config)
        @default = default
        @lookup = {}
        @reserved_keys = methods.map(&:to_s).freeze
      end

      #
      # @return [Pry::Config::Behavior, nil]
      #   The object queried when a key is not found in self.
      #
      def default
        @default
      end

      #
      # @param [#to_s] key
      #
      # @return [Object, BasicObject]
      #   An object
      #
      def [](key)
        key = key.to_s
        obj = key?(key) ? @lookup[key] : (@default && @default[key])
        Pry::Config::Lazy === obj ? obj.call : obj
      end

      #
      # Assigns a key/value pair.
      #
      # @param [#to_s] key
      #
      # @param [Object, BasicObject] value
      #
      # @raise [Pry::Config::ReservedKeyError]
      #   When `key` is a reserved key.
      #
      def []=(key, value)
        key = key.to_s
        if @reserved_keys.include?(key)
          raise ReservedKeyError, "It is not possible to use '#{key}' as a key name, please choose a different key name."
        end

        __push(key,value)
      end

      #
      # Removes `key` from self and allows the next lookup for `key` to
      # traverse back to {#default}.
      #
      # @example
      #   _pry_.config.prompt_name = 'foo'
      #   _pry_.config.forget(:prompt_name)
      #   _pry_.config.prompt_name # => 'pry'
      #
      # @param [#to_s] key
      #
      # @return [void]
      #
      def forget(key)
        key = key.to_s
        __remove(key)
        default.forget(key) if default && default != last_default
      end

      #
      # @example
      #   c = Pry::Config.from_hash(foo: 1)
      #   c.merge!(bar: 2)
      #   c.merge!(Pry::Config.from_hash(baz: 3))
      #
      # @param [Hash, #to_h, #to_hash] other
      #   An object to merge into self.
      #
      # @return [void]
      #
      def merge!(other)
        other = __try_convert_to_hash(other)
        raise TypeError, "unable to convert argument into a Hash" unless other

        other.each do |key, value|
          self[key] = value
        end
      end

      #
      # @example
      #   Pry::Config.from_hash(foo: 1) == {'foo' => 1} # => true
      #   Pry::Config.from_hash(foo: 1) == Pry::Config.from_hash(foo: 1) # => true
      #
      # @param [Hash, #to_h, #to_hash] other
      #   Compares `other` against self.
      #
      # @return [Boolean]
      #   True if self and `other` are considered `eql?`, otherwise false.
      #
      def ==(other)
        return false if !other

        @lookup == __try_convert_to_hash(other)
      end
      alias_method :eql?, :==

      #
      # @example
      #   c = Pry::Config.from_hash(foo: 1)
      #   c.key?(:foo)  # => true
      #   c.key?('foo') # => true
      #
      # @param [#to_s] key
      #
      # @return [Boolean]
      #   True if `key` is stored in self, otherwise false.
      #
      def key?(key)
        key = key.to_s
        @lookup.key?(key)
      end

      #
      # Clears the contents of self.
      #
      # @return [void]
      #
      def clear
        @lookup.clear
        true
      end

      #
      # @return [Array<String>]
      #   An array of keys being stored in self.
      #
      def keys
        @lookup.keys
      end

      #
      # Eagerly loads keys into self directly from {#last_default}.
      #
      # @example
      #
      #  [1] pry(main)> _pry_.config.keys.size
      #   => 13
      #  [2] pry(main)> _pry_.config.eager_load!;
      #  [warning] Pry.config.exception_whitelist is deprecated, please use Pry.config.unrescued_exceptions instead.
      #  [3] pry(main)> _pry_.config.keys.size
      #  => 40
      #
      # @return [Array<String>, nil]
      #   An array of keys inserted into self, or nil if {#last_default} is nil.
      #
      def eager_load!
        return unless last_default

        last_default.keys.each { |key| self[key] = public_send(key) }
      end

      #
      # @example
      #   # _pry_.config -> Pry.config -> Pry::Config.defaults
      #   [1] pry(main)> _pry_.config.last_default
      #
      # @return [Pry::Config::Behaviour]
      #   The last linked default, or nil if there is none.
      #
      def last_default
        last = @default
        last = last.default while last && last.default
        last
      end

      #
      # @return [Hash]
      #   A duplicate copy of the Hash used by self.
      #
      def to_hash
        @lookup.dup
      end
      alias_method :to_h, :to_hash

      def inspect
        key_str = keys.map { |key| "'#{key}'" }.join(",")
        "#<#{__clip_inspect(self)} keys=[#{key_str}] default=#{@default.inspect}>"
      end

      def pretty_print(q)
        q.text inspect[1..-1].gsub(INSPECT_REGEXP, "default=<")
      end

      def method_missing(name, *args, &block)
        key = name.to_s
        if key[-1] == ASSIGNMENT
          short_key = key[0..-2]
          self[short_key] = args[0]
        elsif key?(key)
          self[key]
        elsif @default.respond_to?(name)
          value = @default.public_send(name, *args, &block)
          self[key] = __dup(value)
        else
          nil
        end
      end

      def respond_to_missing?(key, include_all = false)
        key = key.to_s.chomp(ASSIGNMENT)
        key?(key) || @default.respond_to?(key) || super(key, include_all)
      end

      private

      def __clip_inspect(obj)
        "#{obj.class}:0x%x" % obj.object_id
      end

      def __try_convert_to_hash(obj)
        if Hash === obj
          obj
        elsif obj.respond_to?(:to_h)
          obj.to_h
        elsif obj.respond_to?(:to_hash)
          obj.to_hash
        else
          nil
        end
      end

      def __dup(value)
        if NODUP.any? { |klass| klass === value }
          value
        else
          value.dup
        end
      end

      def __push(key,value)
        unless singleton_class.method_defined? key
          define_singleton_method(key) { self[key] }
          define_singleton_method("#{key}=") { |val| @lookup[key] = val }
        end
        @lookup[key] = value
      end

      def __remove(key)
        @lookup.delete(key)
      end
    end
  end
end
