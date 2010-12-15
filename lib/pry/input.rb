require 'readline'

class Pry
  class Input
    trap('INT') { exit }
    
    def read(prompt)
      Readline.readline(prompt, true)
    end
  end

  class SourceInput
    def initialize(file, line)
      @f = File.open(file)
      (line - 1).times { @f.readline }
    end
    
    def read(prompt)
      @f.readline
    end
  end
end
