# frozen_string_literal: true

class Pry
  # Readline replacement for low-capability terminals.
  class StdioInput
    def readline(prompt)
      $stdout.print(prompt)
      $stdin.gets
    end
  end
end
