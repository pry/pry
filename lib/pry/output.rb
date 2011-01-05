class Pry
  class Output
    attr_reader :out
    
    def initialize(out=STDOUT)
      @out = out
    end

    def puts(value)
      out.puts value
    end
  end

  class NullOutput
    def puts(*) end
  end
    
end
