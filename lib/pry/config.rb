class Pry::Config
  require_relative 'config/behavior'
  require_relative 'config/default'
  require_relative 'config/convenience'
  include Pry::Config::Behavior

  def self.shortcuts
    Convenience::SHORTCUTS
  end

  #
  # FIXME
  # @param [Pry::Hooks] hooks
  #
  def hooks=(hooks)
    if hooks.is_a?(Hash)
      warn "Hash-based hooks are now deprecated! Use a `Pry::Hooks` object " \
           "instead! http://rubydoc.info/github/pry/pry/master/Pry/Hooks"
      self["hooks"] = Pry::Hooks.from_hash(hooks)
    else
      self["hooks"] = hooks
    end
  end
end
