class Pry
  class Config < Pry::BasicObject
    # Wraps a block so it can have a name.
    # The primary purpose for instances of this class is to be used as a
    # configuration value that is computed upon each access, see {Pry.lazy}
    # for more information.
    #
    # @example
    #   proc1 = proc {}
    #   proc2 = Pry::Config::Lazy.new(&proc {})
    #
    #   proc1.is_a?(Pry::Config::Lazy)
    #   #=> false
    #   proc2.is_a?(Pry::Config::Lazy)
    #   #=> true
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
