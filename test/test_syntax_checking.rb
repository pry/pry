require 'helper'
describe Pry do

  [
    ["p = '", "'"],
    ["def", "a", "(); end"],
    ["p = <<FOO", "lots", "and", "lots of", "foo", "FOO"],
    ["[", ":lets,", "'list',", "[/nested/", "], things ]"],
    ["abc =~ /hello", "/"],
    ["issue = %W/", "343/"],
    ["pouts(<<HI, 'foo", "bar", "HI", "baz')"],
  ].each do |foo|
    it "should not raise an error on broken lines: #{foo.join("\\n")}" do
      output = StringIO.new
      redirect_pry_io(InputTester.new(*foo), output) do
        Pry.start
      end

      output.string.should.not =~ /SyntaxError/
    end
  end

  [
    ["end"],
    ["puts )("],
    ["1 1"],
    ["puts :"],
    # in this case the syntax error is "expecting ')'".
    ((defined? RUBY_ENGINE && RUBY_ENGINE == "rbx") ? nil : ["def", "method(1"])
  ].compact.each do |foo|
    it "should raise an error on invalid syntax like #{foo.inspect}" do
      output = StringIO.new
      redirect_pry_io(InputTester.new(*foo), output) do
        Pry.start
      end
      output.string.should =~ /SyntaxError/
    end
  end

  it "should not intefere with syntax errors explicitly raised" do
    output = StringIO.new
    redirect_pry_io(InputTester.new(%q{raise SyntaxError, "unexpected $end"}), output) do
      Pry.start
    end
    output.string.should =~ /SyntaxError/
  end
end
