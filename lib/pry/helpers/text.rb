# frozen_string_literal: true

class Pry
  module Helpers
    # The methods defined on {Text} are available to custom commands via
    # {Pry::Command#text}.
    module Text
      extend self

      COLORS = {
        "black" => 30,
        "red" => 31,
        "green" => 32,
        "yellow" => 33,
        "blue" => 34,
        "purple" => 35,
        "magenta" => 35,
        "cyan" => 36,
        "white" => 37
      }.freeze

      COLORS.each_pair do |color, value|
        define_method color do |text|
          "\033[0;#{value}m#{text}\033[0m"
        end

        define_method "bright_#{color}" do |text|
          "\033[1;#{value}m#{text}\033[0m"
        end

        COLORS.each_pair do |bg_color, bg_value|
          define_method "#{color}_on_#{bg_color}" do |text|
            "\033[0;#{value};#{bg_value+10}m#{text}\033[0m"
          end

          define_method "bright_#{color}_on_#{bg_color}" do |text|
            "\033[1;#{value};#{bg_value+10}m#{text}\033[0m"
          end
        end
      end

      # Apply _color_ or style to _text_
      #
      # @param text [String]
      # @param color [nil, Symbol] Color selected from `COLORS`
      # @option bold [nil, true, false]
      # @option faded [nil, true, false]
      # @return [String] Text
      def colorize(text, color = nil, bold: false, faded: false)
        b = []
        b << 1 if bold
        b << 2 if faded
        b << 0 if b.empty?

        escape(text, b, COLORS[color.to_s])
      end

      # Escape _text_ with SGR escape _codes_
      #
      # @param text [String]
      # @param *codes [Integer] SGR code
      def escape(text, *codes)
        seq = codes.compact.join(";")
        "\e[#{seq}m#{text}\e[0m"
      end

      # Remove any color codes from _text_.
      #
      # @param  [String, #to_s] text
      # @return [String] _text_ stripped of any color codes.
      def strip_color(text)
        text.to_s.gsub(/(\001)?\e\[.*?(\d)+m(\002)?/, '')
      end

      # Returns _text_ as bold text for use on a terminal.
      #
      # @param [String, #to_s] text
      # @return [String] _text_
      def bold(text)
        "\e[1m#{text}\e[0m"
      end

      # Returns `text` in the default foreground colour.
      # Use this instead of "black" or "white" when you mean absence of colour.
      #
      # @param [String, #to_s] text
      # @return [String]
      def default(text)
        text.to_s
      end

      #
      # @yield
      #   Yields a block with color turned off.
      #
      # @return [void]
      #
      def no_color
        boolean = Pry.config.color
        Pry.config.color = false
        yield
      ensure
        Pry.config.color = boolean
      end

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
      def with_line_numbers(text, offset, color = :blue)
        lines = text.each_line.to_a
        max_width = (offset + lines.count).to_s.length
        lines.each_with_index.map do |line, index|
          adjusted_index = (index + offset).to_s.rjust(max_width)
          "#{send(color, adjusted_index)}: #{line}"
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
