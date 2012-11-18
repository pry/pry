require 'helper'

describe Pry do
  before do
    @str_output = StringIO.new
  end

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
      redirect_pry_io(InputTester.new(*foo), @str_output) do
        Pry.start
      end

      @str_output.string.should.not =~ /SyntaxError/
    end
  end

  [
    ["end"],
    ["puts )("],
    ["1 1"],
    ["puts :"]
  ] + (Pry::Helpers::BaseHelpers.rbx? ? [] : [
    ["def", "method(1"], # in this case the syntax error is "expecting ')'".
    ["o = Object.new.tap{ def o.render;","'MEH'", "}"] # in this case the syntax error is "expecting keyword_end".
  ]).compact.each do |foo|
    it "should raise an error on invalid syntax like #{foo.inspect}" do
      redirect_pry_io(InputTester.new(*foo), @str_output) do
        Pry.start
      end

      @str_output.string.should =~ /SyntaxError/
    end
  end

  it "should not intefere with syntax errors explicitly raised" do
    redirect_pry_io(InputTester.new(%q{raise SyntaxError, "unexpected $end"}), @str_output) do
      Pry.start
    end

    @str_output.string.should =~ /SyntaxError/
  end

  it "should allow trailing , to continue the line" do
    pry = Pry.new
    Pry::Code.complete_expression?("puts 1, 2,").should == false
  end

  it "should complete an expression that contains a line ending with a ," do
    pry = Pry.new
    Pry::Code.complete_expression?("puts 1, 2,\n3").should == true
  end

  it "should not suppress the error output if the line ends in ;" do
    mock_pry("raise RuntimeError, 'foo';").should =~ /RuntimeError/
  end

  it "should not clobber _ex_ on a SyntaxError in the repl" do
    mock_pry("raise RuntimeError, 'foo'", "puts foo)", "_ex_.is_a?(RuntimeError)").should =~ /^RuntimeError.*\nSyntaxError.*\n=> true/m
  end

  it "should allow whitespace delimeted strings" do
    mock_pry('"%s" %% foo ').should =~ /"foo"/
  end

  it "should allow newline delimeted strings" do
    mock_pry('"%s" %%','foo').should =~ /"foo"/
  end

  it "should allow whitespace delimeted strings ending on the first char of a line" do
    mock_pry('"%s" %% ', ' #done!').should =~ /"\\n"/
  end
end
