# frozen_string_literal: true

# Please keep in mind that any hash signs ("#") in the heredoc strings are
# placed on purpose. Without these editors might remove the whitespace on empty
# lines.
describe Pry::Indent do
  before do
    @indent = Pry::Indent.new(Pry.new)
  end

  it 'should indent an array' do
    input  = "array = [\n10,\n15\n]"
    output = "array = [\n  10,\n  15\n]"

    expect(@indent.indent(input)).to eq output
  end

  it 'should indent a hash' do
    input  = "hash = {\n:name => 'Ruby'\n}"
    output = "hash = {\n  :name => 'Ruby'\n}"

    expect(@indent.indent(input)).to eq output
  end

  it 'should indent a function' do
    input  = "def\nreturn 10\nend"
    output = "def\n  return 10\nend"

    expect(@indent.indent(input)).to eq output
  end

  it 'should indent a module and class' do
    input        = "module Foo\n# Hello world\nend"
    output       = "module Foo\n  # Hello world\nend"
    input_class  = "class Foo\n# Hello world\nend"
    output_class = "class Foo\n  # Hello world\nend"

    expect(@indent.indent(input)).to       eq output
    expect(@indent.indent(input_class)).to eq output_class
  end

  it 'should indent separate lines' do
    expect(@indent.indent('def foo')).to   eq 'def foo'
    expect(@indent.indent('return 10')).to eq '  return 10'
    expect(@indent.indent('end')).to       eq 'end'
  end

  it 'should not indent single line statements' do
    input = <<TXT.strip
def hello; end
puts "Hello"
TXT

    expect(@indent.indent(input)).to eq input
  end

  it 'should handle multiple open and closing tokens on a line' do
    input = <<TXT.strip
[10, 15].each do |num|
puts num
end
TXT

    output = <<TXT.strip
[10, 15].each do |num|
  puts num
end
TXT

    expect(@indent.indent(input)).to eq output
  end

  it 'should properly indent nested code' do
    input = <<TXT.strip
module A
module B
class C
attr_accessor :test
# keep
def number
return 10
end
end
end
end
TXT

    output = <<TXT.strip
module A
  module B
    class C
      attr_accessor :test
      # keep
      def number
        return 10
      end
    end
  end
end
TXT

    expect(@indent.indent(input)).to eq output
  end

  it 'should indent statements such as if, else, etc' do
    input = <<TXT.strip
if a == 10
#
elsif a == 15
#
else
#
end
#
while true
#
end
#
for num in [10, 15, 20]
#
end
#
for num in [10, 15, 20] do
#
end
TXT

    output = <<TXT.strip
if a == 10
  #
elsif a == 15
  #
else
  #
end
#
while true
  #
end
#
for num in [10, 15, 20]
  #
end
#
for num in [10, 15, 20] do
  #
end
TXT

    expect(@indent.indent(input)).to eq output
  end

  it "should correctly handle while <foo> do" do
    input = "while 5 do\n5\nend"
    expect(@indent.indent(input)).to eq "while 5 do\n  5\nend"
  end

  it "should ident case statements" do
    input = <<TXT.strip
case foo
when 1
2
when 2
if 3
4
end
when 5
#
else
#
end
TXT

    output = <<TXT.strip
case foo
when 1
  2
when 2
  if 3
    4
  end
when 5
  #
else
  #
end
TXT

    expect(@indent.indent(input)).to eq output
  end

  it "should indent correctly with nesting" do
    expect(@indent.indent("[[\n[]]\n]")).to eq "[[\n  []]\n]"
    expect(@indent.reset.indent("[[\n[]]\n]")).to eq "[[\n  []]\n]"
    expect(@indent.reset.indent("[[{\n[] =>\n[]}]\n]")).to eq(
      "[[{\n      [] =>\n  []}]\n]"
    )
  end

  it "should not indent single-line ifs" do
    expect(@indent.indent("foo if bar\n#")).to eq "foo if bar\n#"
    expect(@indent.reset.indent("foo() if bar\n#")).to eq "foo() if bar\n#"
    expect(@indent.reset.indent("foo 'hi' if bar\n#")).to eq "foo 'hi' if bar\n#"
    expect(@indent.reset.indent("foo 1 while bar\n#")).to eq "foo 1 while bar\n#"
    expect(@indent.reset.indent("$foo if false\n#")).to eq "$foo if false\n#"
    expect(@indent.reset.indent("@foo if false\n#")).to eq "@foo if false\n#"
    expect(@indent.reset.indent("@@foo if false\n#")).to eq "@@foo if false\n#"
    expect(@indent.reset.indent("super if true\n#")).to eq "super if true\n#"
    expect(@indent.reset.indent("true if false\n#")).to eq "true if false\n#"
    expect(@indent.reset.indent("String if false\n#")).to eq "String if false\n#"
  end

  it "should indent cunningly disguised ifs" do
    expect(@indent.indent("{1 => if bar\n#")).to eq "{1 => if bar\n    #"
    expect(@indent.reset.indent("foo(if bar\n#")).to eq "foo(if bar\n    #"
    expect(@indent.reset.indent("bar(baz, if bar\n#")).to eq "bar(baz, if bar\n    #"
    expect(@indent.reset.indent("[if bar\n#")).to eq "[if bar\n    #"
    expect(@indent.reset.indent("true; while bar\n#")).to eq "true; while bar\n  #"
  end

  it "should differentiate single/multi-line unless" do
    expect(@indent.indent("foo unless bar\nunless foo\nbar\nend")).to eq(
      "foo unless bar\nunless foo\n  bar\nend"
    )
  end

  it "should not indent single/multi-line until" do
    expect(@indent.indent("%w{baz} until bar\nuntil foo\nbar\nend")).to eq(
      "%w{baz} until bar\nuntil foo\n  bar\nend"
    )
  end

  it "should indent begin rescue end" do
    input = <<INPUT.strip
begin
doo :something => :wrong
rescue => e
doit :right
end
INPUT
    output = <<OUTPUT.strip
begin
  doo :something => :wrong
rescue => e
  doit :right
end
OUTPUT

    expect(@indent.indent(input)).to eq output
  end

  it "should not indent single-line rescue" do
    input = <<INPUT.strip
def test
  puts "something" rescue "whatever"
end
INPUT

    expect(@indent.indent(input)).to eq input
  end

  it "should not indent inside strings" do
    expect(@indent.indent(%(def a\n"foo\nbar"\n  end))).to eq %(def a\n  "foo\nbar"\nend)
    expect(@indent.indent(%(def a\nputs %w(foo\nbar), 'foo\nbar'\n  end))).to eq(
      %(def a\n  puts %w(foo\nbar), 'foo\nbar'\nend)
    )
  end

  it "should not indent inside HEREDOCs" do
    expect(@indent.indent(%(def a\nputs <<FOO\n bar\nFOO\nbaz\nend))).to eq(
      %(def a\n  puts <<FOO\n bar\nFOO\n  baz\nend)
    )
    expect(@indent.indent(%(def a\nputs <<-'^^'\n bar\n\t^^\nbaz\nend))).to eq(
      %(def a\n  puts <<-'^^'\n bar\n\t^^\n  baz\nend)
    )
  end

  it "should not indent nested HEREDOCs" do
    input = <<INPUT.strip
def a
puts <<FOO, <<-BAR, "baz", <<-':p'
foo
FOO
bar
BAR
tongue
:p
puts :p
end
INPUT

    output = <<OUTPUT.strip
def a
  puts <<FOO, <<-BAR, "baz", <<-':p'
foo
FOO
bar
BAR
tongue
:p
  puts :p
end
OUTPUT

    expect(@indent.indent(input)).to eq output
  end

  it "should not raise error, if MIDWAY_TOKENS are used without indentation" do
    expect { @indent.indent("when") }.not_to raise_error
    expect { @indent.reset.indent("else") }.not_to raise_error
    expect { @indent.reset.indent("elsif") }.not_to raise_error
    expect { @indent.reset.indent("ensure") }.not_to raise_error
    expect { @indent.reset.indent("rescue") }.not_to raise_error
  end

  describe "nesting" do
    test = File.read("spec/fixtures/example_nesting.rb")

    test.lines.each_with_index do |line, i|
      result = line.split("#").last.strip
      if result == ""
        it "should fail to parse nesting on line #{i + 1} of example_nesting.rb" do
          expect { Pry::Indent.nesting_at(test, i + 1) }
            .to raise_error Pry::Indent::UnparseableNestingError
        end
      else
        it "should parse nesting on line #{i + 1} of example_nesting.rb" do
          # rubocop:disable Security/Eval
          expect(Pry::Indent.nesting_at(test, i + 1)).to eq eval(result)
          # rubocop:enable Security/Eval
        end
      end
    end
  end
end
