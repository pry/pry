require 'readline'

module Pry
  class Input
    def read(prompt)
      Readline.readline(prompt, true)
    end
  end
end
