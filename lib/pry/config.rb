class Pry::Config
  require 'pry/config/behavior'
  require 'pry/config/default'
  require 'pry/config/convenience'
  include Pry::Config::Behavior

  def self.shortcuts
    Convenience::SHORTCUTS
  end

  def self.from_hash(hash, default = nil)
    new(default).tap do |config|
      config.merge!(hash)
    end
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
