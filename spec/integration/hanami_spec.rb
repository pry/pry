require "helper"
require "shellwords"

RSpec.describe "Hanami integration" do
  before :all do
    @ruby = RbConfig.ruby.shellescape
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib')).shellescape
  end

  it "does not enter an infinite loop (#1471, #1621)" do
    skip "prepend is not supported on this version of Ruby" if RUBY_VERSION.start_with? "1.9"
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
    `#@ruby -I#@pry_dir -e'#{code}'`
    expect($?.exitstatus).to eq(42)
  end
end
