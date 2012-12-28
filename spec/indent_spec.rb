require 'helper'

# Please keep in mind that any hash signs ("#") in the heredoc strings are
# placed on purpose. Without these editors might remove the whitespace on empty
# lines.
describe Pry::Indent do
  before do
    @indent = Pry::Indent.new
  end

  it 'should indent an array' do
    input  = "array = [\n10,\n15\n]"
    output = "array = [\n  10,\n  15\n]"

    @indent.indent(input).should == output
  end

  it 'should indent a hash' do
    input  = "hash = {\n:name => 'Ruby'\n}"
    output = "hash = {\n  :name => 'Ruby'\n}"

    @indent.indent(input).should == output
  end

  it 'should indent a function' do
    input  = "def\nreturn 10\nend"
    output = "def\n  return 10\nend"

    @indent.indent(input).should == output
  end

  it 'should indent a module and class' do
    input        = "module Foo\n# Hello world\nend"
    output       = "module Foo\n  # Hello world\nend"
    input_class  = "class Foo\n# Hello world\nend"
    output_class = "class Foo\n  # Hello world\nend"

    @indent.indent(input).should       == output
    @indent.indent(input_class).should == output_class
  end

  it 'should indent separate lines' do
    @indent.indent('def foo').should   == 'def foo'
    @indent.indent('return 10').should == '  return 10'
    @indent.indent('end').should       == 'end'
  end

  it 'should not indent single line statements' do
    input = <<TXT.strip
def hello; end
puts "Hello"
TXT

    @indent.indent(input).should == input
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

    @indent.indent(input).should == output
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

    @indent.indent(input).should == output
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

    @indent.indent(input).should == output
  end

  it "should correctly handle while <foo> do" do
    input = "while 5 do\n5\nend"
    @indent.indent(input).should == "while 5 do\n  5\nend"
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

    @indent.indent(input).should == output
  end

  it "should indent correctly with nesting" do
    @indent.indent("[[\n[]]\n]").should == "[[\n  []]\n]"
    @indent.reset.indent("[[\n[]]\n]").should == "[[\n  []]\n]"
    @indent.reset.indent("[[{\n[] =>\n[]}]\n]").should == "[[{\n      [] =>\n  []}]\n]"
  end

  it "should not indent single-line ifs" do
    @indent.indent("foo if bar\n#").should == "foo if bar\n#"
    @indent.reset.indent("foo() if bar\n#").should == "foo() if bar\n#"
    @indent.reset.indent("foo 'hi' if bar\n#").should == "foo 'hi' if bar\n#"
    @indent.reset.indent("foo 1 while bar\n#").should == "foo 1 while bar\n#"
    @indent.reset.indent("super if true\n#").should == "super if true\n#"
    @indent.reset.indent("true if false\n#").should == "true if false\n#"
    @indent.reset.indent("String if false\n#").should == "String if false\n#"
  end

  it "should indent cunningly disguised ifs" do
    @indent.indent("{1 => if bar\n#").should == "{1 => if bar\n    #"
    @indent.reset.indent("foo(if bar\n#").should == "foo(if bar\n    #"
    @indent.reset.indent("bar(baz, if bar\n#").should == "bar(baz, if bar\n    #"
    @indent.reset.indent("[if bar\n#").should == "[if bar\n    #"
    @indent.reset.indent("true; while bar\n#").should == "true; while bar\n  #"
  end

  it "should differentiate single/multi-line unless" do
    @indent.indent("foo unless bar\nunless foo\nbar\nend").should == "foo unless bar\nunless foo\n  bar\nend"
  end

  it "should not indent single/multi-line until" do
    @indent.indent("%w{baz} until bar\nuntil foo\nbar\nend").should == "%w{baz} until bar\nuntil foo\n  bar\nend"
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

    @indent.indent(input).should == output
  end

  it "should not indent inside strings" do
    @indent.indent(%(def a\n"foo\nbar"\n  end)).should == %(def a\n  "foo\nbar"\nend)
    @indent.indent(%(def a\nputs %w(foo\nbar), 'foo\nbar'\n  end)).should == %(def a\n  puts %w(foo\nbar), 'foo\nbar'\nend)
  end

  it "should not indent inside HEREDOCs" do
    @indent.indent(%(def a\nputs <<FOO\n bar\nFOO\nbaz\nend)).should == %(def a\n  puts <<FOO\n bar\nFOO\n  baz\nend)
    @indent.indent(%(def a\nputs <<-'^^'\n bar\n\t^^\nbaz\nend)).should == %(def a\n  puts <<-'^^'\n bar\n\t^^\n  baz\nend)
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

    @indent.indent(input).should == output
  end

  describe "nesting" do
      test = File.read("spec/fixtures/example_nesting.rb")

      test.lines.each_with_index do |line, i|
        result = line.split("#").last.strip
        if result == ""
          it "should fail to parse nesting on line #{i + 1} of example_nesting.rb" do
            lambda {
              Pry::Indent.nesting_at(test, i + 1)
            }.should.raise(Pry::Indent::UnparseableNestingError)
          end
        else
          it "should parse nesting on line #{i + 1} of example_nesting.rb" do
            Pry::Indent.nesting_at(test, i + 1).should == eval(result)
          end
        end
      end
    end
end
