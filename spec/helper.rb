require 'bundler/setup'
require 'pry/test/helper'
Bundler.require :default, :test
require_relative 'spec_helpers/mock_pry'
require_relative 'spec_helpers/repl_tester'

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

class Module
  public :remove_const
  public :remove_method
end

Pad = Class.new do
  include Pry::Config::Behavior
end.new(nil)

# to help with tracking down bugs that cause an infinite loop in the test suite
if ENV["SET_TRACE_FUNC"]
  require 'set_trace' if Pry::Helpers::BaseHelpers.rbx?
  set_trace_func proc { |event, file, line, id, binding, classname|
     STDERR.printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  }
end

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Pry::Slop v#{Pry::Slop::VERSION}"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before :each do
    # A large number of specs are written in such a way that 'after_session' hooks are not
    # executed. The 'after_session' hook is used by 'Pry::Deprecate' for the removal of stale
    # Pry instances. Eventually the hook not being run causes a big slowdown as a spec run
    # progresses. So, indirectly we clear the data structure holding Pry instance's by calling
    # `__deprecate_yay_bad_tests`.
    Pry::Deprecate.__deprecate_yay_bad_tests
    Pry.config.print_deprecations = false
  end

  config.include Module.new {
    # Pry instances created by the tests don't exec hooks.
    # This works ok, but not best solution to the problem.
    # See '__deprecate_yay_bad_tests' as to why.
    # It's a FIXME, since it would be nice to remove '__deprecate_yay_bad_tests'.
    def simulate_exit(pry)
      pry.eval("exit")
      pry.hooks.exec_hook(:after_session)
    end
  }
  config.include PryTestHelpers
end
