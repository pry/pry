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

  color_enabled = lambda do |pry|
    (pry and return pry.color) or (defined?(_pry_) ? _pry_.color : Pry.color)
  end

  COLORS.each_pair do |color, value|
    define_method(color) do |text, pry=nil|
      instance_exec(pry, &color_enabled) ? "\033[0;#{30+value}m#{text}\033[0m" : text
    end

    define_method("bright_#{color}") do |text, pry=nil|
      instance_exec(pry, &color_enabled) ? "\033[1;#{30+value}m#{text}\033[0m" : text
    end

    COLORS.each_pair do |bg_color, bg_value|
      define_method "#{color}_on_#{bg_color}" do |text, pry=nil|
        instance_exec(pry, &color_enabled) ? "\033[0;#{30 + value};#{40 + bg_value}m#{text}\033[0m" : text
      end

      define_method "bright_#{color}_on_#{bg_color}" do |text, pry=nil|
        instance_exec(pry, &color_enabled) ? "\033[1;#{30 + value};#{40 + bg_value}m#{text}\033[0m" : text
      end
    end
  end

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
    (Pry::Helpers::Colors.instance_methods(false) - [__method__, :no_color]).include?(effect) ?
      public_send(effect, str) : str
  end

  # Returns _text_ as bold text for use on a terminal.
  #
  # @param [String, #to_s] text
  # @return [String] _text_
  def bold text, pry=(defined?(_pry_) && _pry_) || Pry
    (pry and pry.color) ? "\e[1m#{text}\e[0m" : text
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
  def no_color pry=(defined?(_pry_) && _pry_) || Pry, &block
    boolean = pry.config.color
    pry.config.color = false
    yield
  ensure
    pry.config.color = boolean
  end
end
