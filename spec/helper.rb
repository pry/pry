require "bundler/setup"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

require 'mocha/api'
require 'ostruct'
require 'pry/test/helper'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/bacon'
require 'minitest/pride'
require_relative 'spec_helpers/mock_pry'
require_relative 'spec_helpers/repl_tester'

class Module
  public :remove_const
  public :remove_method
end

class Minitest::Spec
  extend  PryTestHelpers
  include PryTestHelpers

  def setup
    Pry.toplevel_binding = nil
    super
  end
end

# turn warnings off (esp for Pry::Hooks which will generate warnings
# in tests)
$VERBOSE = nil

Pad = OpenStruct.new
def Pad.clear
  @table = {}
end

# to help with tracking down bugs that cause an infinite loop in the test suite
if ENV["SET_TRACE_FUNC"]
  require 'set_trace' if Pry::Helpers::BaseHelpers.rbx?
  set_trace_func proc { |event, file, line, id, binding, classname|
     STDERR.printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  }
end

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Slop v#{Slop::VERSION}"
