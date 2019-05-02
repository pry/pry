# frozen_string_literal: true

class Pry
  class Config
    # MemoizedValue is a Proc (block) wrapper. It is meant to be used as a
    # configuration value. Subsequent `#call` calls return the same memoized
    # result.
    #
    # @example
    #   num = 19
    #   value = Pry::Config::MemoizedValue.new { num += 1 }
    #   value.call # => 20
    #   value.call # => 20
    #   value.call # => 20
    #
    # @api private
    # @since ?.?.?
    # @see Pry::Config::LazyValue
    class MemoizedValue
      def initialize(&block)
        @block = block
        @call = nil
      end

      def call
        @call ||= @block.call
      end
    end
  end
end
