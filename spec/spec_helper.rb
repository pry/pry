# frozen_string_literal: true

require 'pry'
require 'rspec'

require 'pry/testable'
require 'English'
require 'stringio'
require 'ostruct'

Dir['./spec/support/**/*.rb'].map do |file|
  require file
end

class Module
  # False positive: https://github.com/rubocop-hq/rubocop/issues/5953
  # rubocop:disable Style/AccessModifierDeclarations
  public :remove_const
  public :remove_method
  # rubocop:enable Style/AccessModifierDeclarations
end

Pad = OpenStruct.new

# to help with tracking down bugs that cause an infinite loop in the test suite
if ENV["SET_TRACE_FUNC"]
  set_trace_func(
    proc { |event, file, line, id, _binding, classname|
      STDERR.printf("%8s %s:%-2d %10s %8s\n", event, file, line, id, classname)
    }
  )
end

RSpec.configure do |config|
  config.order = 'random'

  config.before(:each) do
    Pry::Testable.set_testenv_variables
  end

  config.after(:each) do
    Pry::Testable.unset_testenv_variables
    Pry.reset_defaults
  end
  config.include Pry::Testable::Mockable
  config.include Pry::Testable::Utility
  include Pry::Testable::Evalable
  include Pry::Testable::Variables
end
