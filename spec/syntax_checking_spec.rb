# frozen_string_literal: true

describe Pry do
  before do
    @str_output = StringIO.new
  end

  def error_count_from(code)
    if !Pry::Helpers::Platform.jruby? &&
       defined?(Prism) && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.4.0')
      error_count = Prism.parse(code).errors.length
    else
      begin
        # rubocop:disable Security/Eval
        eval(code)
        # rubocop:enable Security/Eval
      rescue SyntaxError => e
        error_count = e.message.scan(/unexpected.*/).count
      end
    end
    expect(error_count).not_to be_nil

    error_count
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

  examples = [
    ["end"],
    ["puts )("],
    ["1 1"],
    # in this case the syntax error is "expecting keyword_end".
    ["o = Object.new.tap{ def o.render;", "'MEH'", "}"],

    # multiple syntax errors reported in one SyntaxException
    ["puts {key: 'val'}.to_json"]
  ]

  if Gem::Version.new(RUBY_VERSION) <= Gem::Version.new('3.3.0')
    # in this case the syntax error is "expecting ')'".
    examples << ["def", "method(1"]
    examples << ["puts :"]
  end

  examples.compact.each do |foo|
    it "should raise an error on invalid syntax like #{foo.inspect}" do
      redirect_pry_io(InputTester.new(*foo), @str_output) do
        Pry.start
      end

      expect(@str_output.string).to match(/(SyntaxError|syntax errors? found)/)
    end

    it "should display correct number of errors on invalid syntax like #{foo.inspect}" do
      pry_output = mock_pry(*foo)
      errors_found = error_count_from(foo.join("\n"))
      expect(pry_output.scan(/expected.*\n/).count).to eq(errors_found)
    end
  end

  it "should not interfere with syntax errors explicitly raised" do
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

    expect(output).to match(/^RuntimeError.*(SyntaxError|syntax errors).*=> true/m)
  end

  it "should allow whitespace delimited strings" do
    expect(mock_pry('"%s" % % foo ')).to match(/"foo"/)
  end

  it "should allow newline delimited strings" do
    expect(mock_pry('"%s" % %', 'foo')).to match(/"foo"/)
  end

  it "should allow whitespace delimited strings ending on the first char of a line" do
    expect(mock_pry('"%s" % % ', ' #done!')).to match(/"\\n"/)
  end
end
