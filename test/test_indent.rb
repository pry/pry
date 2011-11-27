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
end
