class Pry
  class Config < Pry::BasicObject
    # The primary purpose for instances of this class is to be used as a
    # configuration value that is computed upon each access, see {Pry.lazy}
    # for more examples.
    #
    # @example
    #   num = 19
    #   pry_instance.config.foo = Pry::Config::Lazy.new(&proc { num += 1 })
    #   pry_instance.config.foo # => 20
    #   pry_instance.config.foo # => 21
    #   pry_instance.config.foo # => 22
    #
    # @api private
    # @since v0.12.0
    class Lazy
      def initialize(&block)
        @block = block
      end

      # @return [Object]
      def call
        @block.call
      end
    end
  end
end
