
class Pry
  class Output
    attr_reader :_pry_

    def initialize(_pry_)
      @_pry_ = _pry_
    end

    def puts(str)
      print "#{str.chomp}\n"
    end

    def print(str)
      _pry_.config.output.print decolorize_maybe(str)
    end
    alias << print
    alias write print

    # If _pry_.config.color is currently false, removes ansi escapes from the string.
    def decolorize_maybe(str)
      if _pry_.config.color
        str
      else
        Helpers::Text.strip_color str
      end
    end

    def method_missing(name, *args, &block)
      _pry_.config.output.send(name, *args, &block)
    end

    def respond_to_missing?(*a)
      _pry_.config.respond_to?(*a)
    end
  end
end
