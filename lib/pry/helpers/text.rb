# coding: utf-8
class Pry
  module Helpers
    require_relative "colors"
    # The methods defined on {Text} are available to custom commands via {Pry::Command#text}.
    module Text
      include Pry::Helpers::Colors
      extend self

      # Returns `text` in the default foreground colour.
      # Use this instead of "black" or "white" when you mean absence of colour.
      #
      # @deprecated
      #   Please use {Colors#strip_color} instead.
      #
      # @param [String, #to_s] text
      # @return [String]
      def default text, pry=(defined?(_pry_) && _pry_) || Pry
        pry.output.puts "DEPRECATED: Pry::Helpers::Text#default is deprecated, " \
                        "please use Pry::Helpers::Text#strip_color instead"
        strip_color text.to_s
      end
      alias_method :bright_default, :bold

      # Executes the block with `Pry.config.pager` set to false.
      # @yield
      # @return [void]
      def no_pager pry=(defined?(_pry_) && _pry_) || Pry, &block
        boolean = pry.config.pager
        pry.config.pager = false
        yield
      ensure
        pry.config.pager = boolean
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

      #
      # @note
      #   On JRuby, this method can be slow due to the slow boot times of JRuby.
      #
      # @param [String] char
      #   A string consisting of a single character. Other characters are ignored.
      #
      # @return [Boolean]
      #   Returns true if the terminal Pry is running from displays
      #   _char_ as-is (not as  "?" or other malformed character). This
      #   method is useful when dealing with older terminals not configured
      #   to deal with unicode characters (like MS Windows+cmd.exe).
      #
      def displayable_character?(char)
        displayable_string? char.to_s[0]
      end

      #
      # Same as {#displayable_character?} but operates on entire String instead of single
      # character.
      #
      # @see #displayable_character?
      #
      def displayable_string?(str)
        require 'open3' if not defined?(Open3)
        Open3.popen3 DISPLAY_CMD % {ruby: RbConfig.ruby,
                                    str: str,
                                    impl_specific_options: jruby? ? "--dev --client --disable=gems --disable=did_you_mean" : ""} do |_,out,_|
          str == out.gets.chomp
        end
      end
      DISPLAY_CMD = %q("%{ruby}" %{impl_specific_options} --disable-gems -e 'print "%{str}"').freeze
      SNOWMAN = "☃".freeze
      private_constant :DISPLAY_CMD, :SNOWMAN

      #
      #  @return [Boolean]
      #    Returns true if terminal Pry is running from can display "☃" properly.
      #
      def snowman_ready?
        displayable_character? SNOWMAN
      end
    end
  end
end
