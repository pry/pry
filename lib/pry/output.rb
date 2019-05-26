# frozen_string_literal: true

class Pry
  class Output
    attr_reader :pry_instance

    def initialize(pry_instance)
      @pry_instance = pry_instance
      @output = pry_instance.config.output
    end

    def puts(*objs)
      return print "\n" if objs.empty?

      objs.each do |obj|
        if (ary = Array.try_convert(obj))
          puts(*ary)
        else
          print "#{obj.to_s.chomp}\n"
        end
      end
      nil
    end

    def print(*objs)
      objs.each do |obj|
        @output.print decolorize_maybe(obj.to_s)
      end
      nil
    end
    alias << print
    alias write print

    def tty?
      @output.respond_to?(:tty?) && @output.tty?
    end

    def method_missing(method_name, *args, &block)
      if @output.respond_to?(method_name)
        @output.__send__(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @output.respond_to?(method_name, include_private)
    end

    def decolorize_maybe(str)
      if pry_instance.config.color
        str
      else
        Pry::Helpers::Text.strip_color str
      end
    end
  end
end
