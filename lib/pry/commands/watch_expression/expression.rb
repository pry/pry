class Pry
  class Command::WatchExpression
    class Expression
      NODUP = [TrueClass, FalseClass, NilClass, Numeric].freeze
      attr_reader :target, :source, :value, :previous_value

      def initialize(target, source)
        @target = target
        @source = source
      end

      def eval!
        @previous_value = value
        @value = target_eval(target, source)
        @value = @value.dup unless NODUP.any? { |klass| klass === @value }
      end

      def to_s
        "#{print_source} => #{print_value}"
      end

      def changed?
        (value != previous_value)
      end

      def print_value
        Pry::ColorPrinter.pp(value, "")
      end

      def print_source
        Code.new(source).strip
      end

      private

      def target_eval(target, source)
        target.eval(source)
      rescue => e
        e
      end
    end
  end
end
