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
    `#@ruby -I #@pry_dir -e '
      require "pry"
      p defined? Readline
    '`.should == "nil\n"
  end

  it "is loaded on invoking 'pry'" do
    `#@ruby -I #@pry_dir -e '
      require "pry"
      Pry.start self, input: StringIO.new("exit-all\n"), output: StringIO.new
      puts # put newline after ANSI junk printed by readline
      p defined?(Readline)
    '`.split("\n").last.should == '"constant"'
  end
end
