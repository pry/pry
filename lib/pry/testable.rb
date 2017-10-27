# good idea ???
# if you're testing pry plugin you should require pry by yourself, no?
require 'pry' if not defined?(Pry)

module Pry::Testable
  extend self
  require_relative "testable/pry_tester"
  require_relative "testable/evalable"
  require_relative "testable/mockable"
  require_relative "testable/utility"

  def self.included(mod)
    mod.module_eval do
      include Pry::Testable::Mockable
      include Pry::Testable::Evalable
      include Pry::Testable::Utility
    end
  end

  def prepare_config!
    Pry.config.color = false
    Pry.config.pager = false
    Pry.config.should_load_rc       = false
    Pry.config.should_load_local_rc = false
    Pry.config.should_load_plugins  = false
    Pry.config.history.should_load  = false
    Pry.config.history.should_save  = false
    Pry.config.correct_indent       = false
    Pry.config.hooks                = Pry::Hooks.new
    Pry.config.collision_warning    = false
  end
end
