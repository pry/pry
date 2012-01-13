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
    (Pry::Helpers::BaseHelpers.rbx? ? nil : ["def", "method(1"])
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

  it "should allow trailing , to continue the line" do
    pry = Pry.new

    pry.complete_expression?("puts 1, 2,").should == false
  end

  it "should complete an expression that contains a line ending with a ," do
    pry = Pry.new
    pry.complete_expression?("puts 1, 2,\n3").should == true
  end

  it "should not clobber _ex_ on a SyntaxError in the repl" do

    mock_pry("raise RuntimeError, 'foo';", "puts foo)", "_ex_.is_a?(RuntimeError)").should =~ /^RuntimeError.*\nSyntaxError.*\n=> true/m
  end
end
