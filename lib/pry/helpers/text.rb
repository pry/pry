class Pry
  module Helpers
    # The methods defined on {Text} are available to custom commands via {Pry::Command#text}.
    module Text
      include Pry::Color
      extend Pry::Color
      #
      # @yield
      #   Yields a block with paging turned off.
      #
      # @return [void]
      #
      def no_pager
        boolean = Pry.config.pager
        Pry.config.pager = false
        yield
      ensure
        Pry.config.pager = boolean
      end

      # Returns _text_ in a numbered list, beginning at _offset_.
      #
      # @param  [#each_line] text
      # @param  [Fixnum] offset
      # @return [String]
      def with_line_numbers(text, offset, color=:blue)
        lines = text.each_line.to_a
        max_width = (offset + lines.count).to_s.length
        lines.each_with_index.map do |line, index|
          adjusted_index = (index + offset).to_s.rjust(max_width)
          "#{self.send(color, adjusted_index)}: #{line}"
        end.join
      end

      # Returns _text_ indented by _chars_ spaces.
      #
      # @param [String] text
      # @param [Fixnum] chars
      def indent(text, chars)
        text.lines.map { |l| "#{' ' * chars}#{l}" }.join
      end
    end
  end
end
