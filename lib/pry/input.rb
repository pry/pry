require 'readline'

class Pry
  class Input
    def read(prompt)
      Readline.readline(prompt, true)
    end
  end
end
