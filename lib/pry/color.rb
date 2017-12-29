module Pry::Color
  extend self
  COLORS = {
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
  BRUSH_METHODS = [*COLORS.keys, *["bold", "default", "bright_default", "strip_color"]]
  UnknownBrushError = Class.new(RuntimeError)

  COLORS.each_pair do |color, value|
    define_method color do |text, pry=((defined?(_pry_) and _pry_) or Pry)|
      pry.color ? "\033[0;#{30+value}m#{text}\033[0m" : text
    end

    define_method "bright_#{color}" do |text, pry=((defined?(_pry_) and _pry_) or Pry)|
      pry.color ? "\033[1;#{30+value}m#{text}\033[0m" : text
    end
    BRUSH_METHODS.push "bright_#{color}"

    COLORS.each_pair do |bg_color, bg_value|
      define_method "#{color}_on_#{bg_color}" do |text, pry=((defined?(_pry_) and _pry_) or Pry)|
        pry.color ? "\033[0;#{30 + value};#{40 + bg_value}m#{text}\033[0m" : text
      end

      define_method "bright_#{color}_on_#{bg_color}" do |text, pry=((defined?(_pry_) and _pry_) or Pry)|
        pry.color ? "\033[1;#{30 + value};#{40 + bg_value}m#{text}\033[0m" : text
      end
      BRUSH_METHODS.concat ["#{color}_on_#{bg_color}", "bright_#{color}_on_#{bg_color}"]
    end
  end

  #
  #
  # @example
  #   paint "foo", :bold
  #
  # @param [String] str
  #   The string to paint.
  #
  # @param [String, Symbol] brush
  #   The brush to paint 'str' with.
  #
  def paint str, brush, pry=((defined?(_pry_) and _pry_) or Pry)
    if BRUSH_METHODS.include?(brush.to_s)
      public_send brush, str, pry
    else
      raise UnknownBrushError, "#{brush} is not a known brush"
    end
  end

  # Remove any color codes from _text_.
  #
  # @param  [String, #to_s] text
  # @return [String] _text_ stripped of any color codes.
  def strip_color text, pry=((defined?(_pry_) and _pry_) or Pry)
    text.to_s.gsub(/(\001)?\e\[.*?(\d)+m(\002)?/ , '')
  end

  # Returns _text_ as bold text for use on a terminal.
  #
  # @param [String, #to_s] text
  # @return [String] _text_
  def bold text, pry=((defined?(_pry_) and _pry_) or Pry)
    pry.color ? "\e[1m#{text}\e[0m" : text
  end

  # Returns `text` in the default foreground colour.
  # Use this instead of "black" or "white" when you mean absence of colour.
  #
  # @param [String, #to_s] text
  # @return [String]
  def default text, pry=((defined?(_pry_) and _pry_) or Pry)
    text.to_s
  end
  alias_method :bright_default, :bold

  #
  # @yield
  #   Yields a block with color turned off.
  #
  # @return [void]
  #
  def no_color pry=((defined?(_pry_) and _pry_) or Pry)
    boolean = Pry.config.color
    Pry.config.color = false
    yield
  ensure
    Pry.config.color = boolean
  end
end
