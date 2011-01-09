class Pry

  # default output class - just writes to STDOUT
  class Output
    attr_reader :out
    
    def initialize(out=STDOUT)
      @out = out
    end

    def puts(value)
      out.puts value
    end
  end

  # null output class - doesn't write anywwhere.
  class NullOutput
    def puts(*) end
  end
end
