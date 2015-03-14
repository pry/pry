class Pry::Config
  require_relative 'config/behavior'
  require_relative 'config/default'
  require_relative 'config/convenience'
  include Pry::Config::Behavior

  def self.shortcuts
    Convenience::SHORTCUTS
  end
end
