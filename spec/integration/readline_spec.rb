# frozen_string_literal: true

# These specs ensure that Pry doesn't require readline until the first time a
# REPL is started.

require 'rbconfig'

RSpec.describe "Readline", slow: true do
  before :all do
    @ruby = RbConfig.ruby
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib'))
  end

  it "is not loaded on requiring 'pry'" do
    code = <<-RUBY
      require "pry"
      p defined?(Readline)
    RUBY
    out = IO.popen([@ruby, '-I', @pry_dir, '-e', code, err: [:child, :out]], &:read)
    expect(out).to eq("nil\n")
  end

  it "is loaded on invoking 'pry'" do
    code = <<-RUBY
      require "pry"
      Pry.start self, input: StringIO.new("exit-all"), output: StringIO.new
      puts defined?(Readline)
    RUBY
    out = IO.popen([@ruby, '-I', @pry_dir, '-e', code, err: [:child, :out]], &:read)
    expect(out).to end_with("constant\n")
  end

  it "is not loaded on invoking 'pry' if Pry.input is set" do
    code = <<-RUBY
      require "pry"
      Pry.input = StringIO.new("exit-all")
      Pry.start self, output: StringIO.new
      p defined?(Readline)
    RUBY
    out = IO.popen([@ruby, '-I', @pry_dir, '-e', code, err: [:child, :out]], &:read)
    expect(out).to end_with("nil\n")
  end
end
