require 'bundler/setup'
require 'pry/test/helper'
Bundler.require :default, :test
require_relative 'spec_helpers/bacon'
require_relative 'spec_helpers/mock_pry'
require_relative 'spec_helpers/repl_tester'

Pad = Class.new do
  include Pry::Config::Behavior
end.new(nil)

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Slop v#{Slop::VERSION}"
