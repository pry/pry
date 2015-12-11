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

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Pry::Pry::Slop v#{Pry::Pry::Slop::VERSION}"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.include PryTestHelpers
end
