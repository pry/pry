class Pry
  class Config < Pry::BasicObject
    include Behavior

    def self.shortcuts
      Convenience::SHORTCUTS
    end
  end
end
