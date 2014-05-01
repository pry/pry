
class Pry
  class Output
    attr_reader :_pry_
    def initialize(_pry_)
      @_pry_ = _pry_
    end

    def puts(str)
      print "#{str.chomp}\n"
    end

    def print str
      if _pry_.config.color
        _pry_.config.output.print str
      else
        _pry_.config.output.print Helpers::Text.strip_color str
      end
    end
    alias << print
    alias write print

    def method_missing(name, *args, &block)
      _pry_.config.output.send(name, *args, &block)
    end

    def respond_to_missing?(*a)
      _pry_.config.respond_to?(*a)
    end
  end
end
