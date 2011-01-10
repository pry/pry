require 'readline'

class Pry

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
