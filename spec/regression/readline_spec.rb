# These specs ensure that Pry doesn't require readline until the first time a
# REPL is started.

require "helper"
require "shellwords"

describe "Readline" do
  before do
    @ruby    = RbConfig.ruby.shellescape
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib')).shellescape
  end

  it "is not loaded on requiring 'pry'" do
    code = <<-RUBY
      require "pry"
      p defined?(Readline)
    RUBY
    expect(`#@ruby -I #@pry_dir -e '#{code}'`).to eq("nil\n")
  end

  it "is loaded on invoking 'pry'" do
    code = <<-RUBY
      require "pry"
      Pry.start self, input: StringIO.new("exit-all"), output: StringIO.new
      puts defined?(Readline)
    RUBY
    expect(`#@ruby -I #@pry_dir -e '#{code}'`.end_with?("constant\n")).to eq(true)
  end

  it "causes the terminal to no longer echo commands" do
    skip "tty not present" unless $stdout.respond_to?(:tty?)
    skip "cannot fork" if RUBY_PLATFORM =~ /java/

    code = <<-RUBY
      require "pry"
      puts Process.pid
      binding.pry
    RUBY
    tty_state_before = `stty -g`
    pid_that_will_eat_your_echo = fork do
      `#@ruby -I #@pry_dir -e '#{code}'`.chomp
    end
    Process.kill 'INT', pid_that_will_eat_your_echo
    at_exit do
      is_dev_tty_still_there = !open("/dev/tty", "w").closed?
      expect(is_dev_tty_still_there).to eq(true)
      tty_state_after = `stty -g`
      expect(tty_state_after).to eq(tty_state_before)
    end
  end

  it "is not loaded on invoking 'pry' if Pry.input is set" do
    code = <<-RUBY
      require "pry"
      Pry.input = StringIO.new("exit-all")
      Pry.start self, output: StringIO.new
      p defined?(Readline)
    RUBY
    expect(`#@ruby -I #@pry_dir -e '#{code}'`.end_with?("nil\n")).to eq(true)
  end
end
