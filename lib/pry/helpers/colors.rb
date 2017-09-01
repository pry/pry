module Pry::Helpers::Colors
  extend self
  COLORS =
    {
      "black"   => 0,
      "red"     => 1,
      "green"   => 2,
      "yellow"  => 3,
      "blue"    => 4,
      "purple"  => 5,
      "magenta" => 5,
      "cyan"    => 6,
      "white"   => 7
    }

  #
  #  @example
  #
  #    paint "foo", :green
  #    paint "bar", :red
  #    paint "baz", :bold
  #
  #  @param [String] str
  #    String to paint.
  #
  #  @param [Symbol]
  #    The effect to apply to _str_.
  #
  #  @return [String]
  #    Returns a string with _effect_ applied, or _str_ if the effect is unknown.
  #
  def paint(str, effect)
    instance_methods(false).include?(effect) ? public_send(effect, str) : str
  end

  COLORS.each_pair do |color, value|
    define_method color do |text|
      "\033[0;#{30+value}m#{text}\033[0m"
    end

    define_method "bright_#{color}" do |text|
      "\033[1;#{30+value}m#{text}\033[0m"
    end

    COLORS.each_pair do |bg_color, bg_value|
      define_method "#{color}_on_#{bg_color}" do |text|
        "\033[0;#{30 + value};#{40 + bg_value}m#{text}\033[0m"
      end

      define_method "bright_#{color}_on_#{bg_color}" do |text|
        "\033[1;#{30 + value};#{40 + bg_value}m#{text}\033[0m"
      end
    end
  end

  # Returns _text_ as bold text for use on a terminal.
  #
  # @param [String, #to_s] text
  # @return [String] _text_
  def bold(text)
    "\e[1m#{text}\e[0m"
  end

  # Remove any color codes from _text_.
  #
  # @param  [String, #to_s] text
  # @return [String] _text_ stripped of any color codes.
  def strip_color(text)
    text.to_s.gsub(/(\001)?\e\[.*?(\d)+m(\002)?/ , '')
  end

  # Executes the block with `Pry.config.color` set to false.
  # @yield
  # @return [void]
  def no_color(&block)
    boolean = Pry.config.color
    Pry.config.color = false
    yield
  ensure
    Pry.config.color = boolean
  end
end
