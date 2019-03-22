class Pry
  class Output
    attr_reader :pry_instance

    def initialize(pry_instance)
      @pry_instance = pry_instance
      @boxed_io = pry_instance.config.output
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
        @boxed_io.print decolorize_maybe(obj.to_s)
      end
      nil
    end
    alias << print
    alias write print

    def tty?
      @boxed_io.respond_to?(:tty?) && @boxed_io.tty?
    end

    def method_missing(name, *args, &block)
      @boxed_io.__send__(name, *args, &block)
    end

    def respond_to_missing?(m, include_all = false)
      @boxed_io.respond_to?(m, include_all)
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
