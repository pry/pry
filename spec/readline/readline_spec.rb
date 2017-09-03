require "helper"
require "shellwords"
describe "Readline" do
  before do
    @ruby    = RbConfig.ruby.shellescape
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib')).shellescape
  end

  it "is initialized properly" do
    code = <<-RUBY
    require "readline"
    require "pry"
    pry = Pry.new(input: Readline)
    Kernel.print pry.input.completer_word_break_characters
    RUBY
    expect(`#@ruby -I#@pry_dir -e'#{code}'`).to eq(Pry::READLINE_BREAK_CHARS)
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
