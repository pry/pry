# frozen_string_literal: true

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
    ["pouts(<<HI, 'foo", "bar", "HI", "baz')"]
  ].each do |foo|
    it "should not raise an error on broken lines: #{foo.join('\\n')}" do
      redirect_pry_io(InputTester.new(*foo), @str_output) do
        Pry.start
      end

      expect(@str_output.string).not_to match(/SyntaxError/)
    end
  end

  [
    ["end"],
    ["puts )("],
    ["1 1"],
    ["puts :"],

    # in this case the syntax error is "expecting ')'".
    ["def", "method(1"],

    # in this case the syntax error is "expecting keyword_end".
    ["o = Object.new.tap{ def o.render;", "'MEH'", "}"],

    # multiple syntax errors reported in one SyntaxException
    ["puts {'key'=>'val'}.to_json"]
  ].compact.each do |foo|
    it "should raise an error on invalid syntax like #{foo.inspect}" do
      redirect_pry_io(InputTester.new(*foo), @str_output) do
        Pry.start
      end

      expect(@str_output.string).to match(/SyntaxError/)
    end

    it "should display correct number of errors on invalid syntax like #{foo.inspect}" do
      begin
        # rubocop:disable Security/Eval
        eval(foo.join("\n"))
        # rubocop:enable Security/Eval
      rescue SyntaxError => e
        error_count = e.message.scan(/syntax error/).count
      end
      expect(error_count).not_to be_nil

      pry_output = mock_pry(*foo)
      expect(pry_output.scan(/SyntaxError/).count).to eq(error_count)
    end
  end

  it "should not intefere with syntax errors explicitly raised" do
    input_tester = InputTester.new('raise SyntaxError, "unexpected $end"')
    redirect_pry_io(input_tester, @str_output) do
      Pry.start
    end

    expect(@str_output.string).to match(/SyntaxError/)
  end

  it "should allow trailing , to continue the line" do
    expect(Pry::Code.complete_expression?("puts 1, 2,")).to eq false
  end

  it "should complete an expression that contains a line ending with a ," do
    expect(Pry::Code.complete_expression?("puts 1, 2,\n3")).to eq true
  end

  it "should not suppress the error output if the line ends in ;" do
    expect(mock_pry("raise RuntimeError, 'foo';")).to match(/RuntimeError/)
  end

  it "should not clobber _ex_ on a SyntaxError in the repl" do
    output = mock_pry(
      "raise RuntimeError, 'foo'",
      "puts foo)",
      "_ex_.is_a?(RuntimeError)"
    )
    expect(output).to match(/^RuntimeError.*\nSyntaxError.*\n=> true/m)
  end

  it "should allow whitespace delimeted strings" do
    expect(mock_pry('"%s" % % foo ')).to match(/"foo"/)
  end

  it "should allow newline delimeted strings" do
    expect(mock_pry('"%s" % %', 'foo')).to match(/"foo"/)
  end

  it "should allow whitespace delimeted strings ending on the first char of a line" do
    expect(mock_pry('"%s" % % ', ' #done!')).to match(/"\\n"/)
  end
end
