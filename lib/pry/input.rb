require 'readline'

class Pry
  class Input
    trap('INT') { exit }
    
    def read(prompt)
      Readline.readline(prompt, true)
    end
  end

  class FileInput
    def initialize(file, line = 1)
      @f = File.open(file)
      (line - 1).times { @f.readline }
    end
    
    def read(prompt)
      @f.readline
    end
  end
end
