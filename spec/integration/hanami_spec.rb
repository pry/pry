# frozen_string_literal: true

require 'rbconfig'

RSpec.describe "Hanami integration", slow: true do
  before :all do
    @ruby = RbConfig.ruby
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib'))
  end

  it "does not enter an infinite loop (#1471, #1621)" do
    if RUBY_VERSION.start_with? "1.9"
      skip "prepend is not supported on this version of Ruby"
    end
    code = <<-RUBY
        require "pry"
        require "timeout"
        module Prepend1
          def call(arg)
            super
          end
        end
        module Prepend2
          def call(arg)
            super
          end
        end
        class Action
          prepend Prepend1
          prepend Prepend2
          def call(arg)
            binding.pry input: StringIO.new("exit"), output: StringIO.new
          end
        end
        Timeout.timeout(1) { Action.new.call("define prison, in the abstract sense") }
        exit 42
    RUBY
    IO.popen([@ruby, '-I', @pry_dir, '-e', code, err: [:child, :out]], &:read)
    expect($CHILD_STATUS.exitstatus).to eq(42)
  end
end
