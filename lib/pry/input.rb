require 'readline'

class Pry

  # default input class - uses Readline.
  class Input
    trap('INT') { exit }
    
    def readline(prompt)
      Readline.readline(prompt, true)
    end
  end

  # read from any IO-alike
  class IOInput
    def initialize(io)
      @io = io
    end

    def readline
      @io.readline
    end

    def close
      @io.close
    end
  end

  # file input class
  class FileInput
    def initialize(file, line = 1)
      @f = File.open(file)
      (line - 1).times { @f.readline }
    end
    
    def readline(prompt)
      @f.readline
    end

    def close
      @f.close
    end
  end

  # preset input class
  class PresetInput
    def initialize(*actions)
      @orig_actions = actions.dup
      @actions = actions
    end

    def readline(*)
      @actions.shift
    end

    def rewind
      @actions = @orig_actions.dup
    end
  end
end
