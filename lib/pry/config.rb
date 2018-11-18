class Pry
  # The Pry config.
  # @api public
  class Config < Pry::BasicObject
    include Behavior

    def self.shortcuts
      Convenience::SHORTCUTS
    end
  end
end
