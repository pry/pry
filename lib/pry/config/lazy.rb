class Pry
  class Config < Pry::BasicObject
    # The primary purpose for instances of this class is to be used as a
    # configuration value that is computed upon each access, see {Pry.lazy}
    # for more examples.
    #
    # @example
    #   num = 19
    #   _pry_.config.foo = Pry::Config::Lazy.new(&proc { num += 1 })
    #   _pry_.config.foo # => 20
    #   _pry_.config.foo # => 21
    #   _pry_.config.foo # => 22
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
