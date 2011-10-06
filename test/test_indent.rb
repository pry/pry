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

    @indent.indent(input).should === output
  end

  it 'should indent a hash' do
    input  = "hash = {\n:name => 'Ruby'\n}"
    output = "hash = {\n  :name => 'Ruby'\n}"

    @indent.indent(input).should === output
  end

  it 'should indent a function' do
    input  = "def\nreturn 10\nend"
    output = "def\n  return 10\nend"

    @indent.indent(input).should === output
  end

  it 'should indent a module and class' do
    input        = "module Foo\n# Hello world\nend"
    output       = "module Foo\n  # Hello world\nend"
    input_class  = "class Foo\n# Hello world\nend"
    output_class = "class Foo\n  # Hello world\nend"

    @indent.indent(input).should       === output
    @indent.indent(input_class).should === output_class
  end

  it 'should indent separate lines' do
    @indent.indent('def foo').should   === 'def foo'
    @indent.indent('return 10').should === '  return 10'
    @indent.indent('end').should       === 'end'
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

    @indent.indent(input).should === output
  end

  it 'should indent statements such as if, else, etc' do
    input = <<TXT.strip
if a === 10
#
elsif a === 15
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
if a === 10
  #
elsif a === 15
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

    @indent.indent(input).should === output
  end
end
