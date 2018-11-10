class Pry
  # The Pry config.
  # @api public
  class Config < Pry::BasicObject
    # Wraps a block so it can have a name.
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

    include Behavior

    def self.shortcuts
      Convenience::SHORTCUTS
    end

    def prompt=(obj)
      is_prompt_object = lambda do |prompt|
        ::Hash === prompt and
        prompt.key?(:description) and
        prompt.key?(:value)
      end
      super(is_prompt_object.call(obj) ? obj[:value] : obj)
    end
  end
end
