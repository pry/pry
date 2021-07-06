# frozen_string_literal: true

class Pry
  module Helpers
    # The methods defined on {Text} are available to custom commands via
    # {Pry::Command#text}.
    module Text
      extend self

      DECORATIONS = {
        "bold" => '1',
        "faint" => '2',
        "italic" => '3',
        "underline" => '4',
        "blink" => '5',
        "reverse" => '7'
      }.freeze

      COLORS = {
        "black" => '0',
        "red" => '1',
        "green" => '2',
        "yellow" => '3',
        "blue" => '4',
        "purple" => '5',
        "magenta" => '5',
        "cyan" => '6',
        "white" => '7'
      }.freeze

      DECORATIONS.each_pair do |decoration, color_code|
        define_method decoration do |text|
          escape_text(color_code, text)
        end
      end

      COLORS.each_pair do |color, value|
        color_code = "0;3#{value}"
        define_method color do |text|
          escape_text(color_code, text)
        end

        bright_color_code = "1;3#{value}"
        define_method "bright_#{color}" do |text|
          escape_text(bright_color_code, text)
        end

        COLORS.each_pair do |bg_color, bg_value|
          bg_color_code = "#{color_code};4#{bg_value}"
          define_method "#{color}_on_#{bg_color}" do |text|
            escape_text(bg_color_code, text)
          end

          bright_bg_color_code = "#{bright_color_code};4#{bg_value}"
          define_method "bright_#{color}_on_#{bg_color}" do |text|
            escape_text(bright_bg_color_code, text)
          end
        end
      end

      # @param color_code [String]
      # @param text [String]
      # @return [String]
      def escape_text(color_code, text)
        "\e[#{color_code}m#{text}\e[0m"
      end

      # Remove any color codes from _text_.
      #
      # @param  [String, #to_s] text
      # @return [String] _text_ stripped of any color codes.
      def strip_color(text)
        text.to_s.gsub(/\001|\002|\e\[[\d;]*m/, '')
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
