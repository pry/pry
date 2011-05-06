class Pry
  module Helpers

    module Color
 
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

      COLORS.each_pair do |color, value|
        define_method color do |text|
          Pry.color ? "\033[0;#{30+value}m#{text}\033[0m" : text.to_s
        end

        define_method "bright_#{color}" do |text|
          Pry.color ? "\033[1;#{30+value}m#{text}\033[0m" : text.to_s
        end
      end

      def strip_color text
        text.gsub /\e\[.*?(\d)+m/, ''
      end

      def bold text
        Pry.color ? "\e[1m#{text}\e[0m" : text.to_s
      end

      def no_color &block
        boolean = Pry.color
        Pry.color = false
        yield
      ensure
        Pry.color = boolean
      end

    end

  end
end

