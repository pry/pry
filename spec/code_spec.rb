# frozen_string_literal: true

require 'method_source'
require 'tempfile'

RSpec.describe Pry::Code do
  describe "Pry::Code()" do
    context "when given a Code object" do
      it "returns the passed parameter unchanged" do
        code = described_class.new
        expect(Pry::Code(code)).to eql(code)
      end
    end

    context "when given a Method" do
      def bound_method
        :test
      end

      it "reads lines from bound method" do
        expect(Pry::Code(method(:bound_method)).to_s).to eq(
          "def bound_method\n  :test\nend\n"
        )
      end
    end

    context "when given an UnboundMethod" do
      def unbound_method
        :test
      end

      it "reads lines from unbound methods" do
        unbound_method = method(:unbound_method).unbind
        expect(Pry::Code(unbound_method).to_s).to eq(
          "def unbound_method\n  :test\nend\n"
        )
      end
    end

    context "when given a Proc" do
      it "reads lines from proc" do
        proc = proc { :proc }
        expect(Pry::Code(proc).to_s).to eq("proc = proc { :proc }\n")
      end
    end

    context "when given a Pry::Method" do
      def bound_method
        :test
      end

      it "reads lines from Pry::Method" do
        method = Pry::Method(method(:bound_method))
        expect(Pry::Code(method).to_s).to eq("def bound_method\n  :test\nend\n")
      end
    end

    context "when given an Array" do
      it "reads lines from the array" do
        expect(Pry::Code(%w[1 2 3]).length).to eq(3)
      end
    end
  end

  describe ".from_file" do
    it "reads lines from a file on disk" do
      expect(described_class.from_file(__FILE__).length).to be > 0
    end

    it "sets code type according to the file" do
      expect(described_class.from_file(__FILE__).code_type).to eq(:ruby)
    end

    it "raises error when file doesn't exist" do
      expect { Pry::Code.from_file('abcd') }
        .to raise_error(MethodSource::SourceNotFoundError)
    end

    it "reads lines from a file relative to origin pwd" do
      filename = 'spec/' + File.basename(__FILE__)
      Dir.chdir('spec') do
        expect(described_class.from_file(filename).length).to be > 0
      end
    end

    it "reads lines from a file relative to origin pwd with '.rb' omitted" do
      filename = 'spec/' + File.basename(__FILE__, '.*')
      Dir.chdir('spec') do
        expect(described_class.from_file(filename).code_type).to eq(:ruby)
      end
    end

    it "reads lines from a file relative to current pwd" do
      filename = File.basename(__FILE__)
      Dir.chdir('spec') do
        expect(described_class.from_file(filename).length).to be > 0
      end
    end

    context "when readling lines from Pry's line buffer" do
      it "reads entered lines" do
        pry_eval ':hello'
        expect(described_class.from_file('(pry)').to_s).to eq(":hello\n")
      end

      it "can specify file type manually" do
        expect(described_class.from_file('(pry)', :c).code_type).to eq(:c)
      end
    end

    context "when reading lines from a file without an extension" do
      it "sets code type to :unknown" do
        temp_file('') do |f|
          expect(described_class.from_file(f.path).code_type).to eq(:unknown)
        end
      end
    end

    context "when reading files from $LOAD_PATH" do
      before { $LOAD_PATH << 'spec/fixtures' }
      after { $LOAD_PATH.delete('spec/fixtures') }

      it "finds files with '.rb' extensions" do
        expect(described_class.from_file('slinky.rb').code_type).to eq(:ruby)
      end

      it "finds Ruby files with omitted '.rb' extension" do
        expect(described_class.from_file('slinky').code_type).to eq(:ruby)
      end

      it "finds files in a relative directory with '.rb' extension" do
        expect(described_class.from_file('../spec_helper.rb').code_type).to eq(:ruby)
      end

      it "finds files in a relative directory with '.rb' omitted" do
        expect(described_class.from_file('../spec_helper').code_type).to eq(:ruby)
      end

      it "doesn't confuse files with the same name, but without an extension" do
        expect(described_class.from_file('cat_load_path').code_type).to eq(:unknown)
      end

      it "doesn't confuse files with the same name, but with an extension" do
        expect(described_class.from_file('cat_load_path.rb').code_type).to eq(:ruby)
      end

      it "recognizes Gemfile as a Ruby file" do
        expect(described_class.from_file('Gemfile').code_type).to eq(:ruby)
      end
    end
  end

  describe ".from_method" do
    it "reads lines from a method's definition" do
      method = Pry::Method.from_obj(described_class, :from_method)
      expect(described_class.from_method(method).length).to be > 0
    end
  end

  describe ".from_module" do
    it "reads line from a class" do
      expect(described_class.from_module(described_class).length).to be > 0
    end

    it "sets code type to :ruby" do
      expect(described_class.from_module(described_class).code_type).to eq(:ruby)
    end
  end

  describe "#push" do
    it "is an alias of #<<" do
      expect(subject.method(:push)).to eq(subject.method(:<<))
    end

    it "appends lines to the code" do
      subject.push('1')
      subject.push('1')
      expect(subject.length).to eq(2)
    end
  end

  describe "#select" do
    it "returns a code object" do
      expect(subject.select {}).to be_a(described_class)
    end

    it "selects lines matching a condition" do
      subject.push('matching-foo')
      subject.push('nonmatching-bar')
      subject.push('matching-baz')

      selected = subject.select do |line_of_code|
        line_of_code.line.start_with?('matching')
      end
      expect(selected.lines).to eq(["matching-foo\n", "matching-baz\n"])
    end
  end

  describe "#reject" do
    it "returns a code object" do
      expect(subject.reject {}).to be_a(described_class)
    end

    it "rejects lines matching a condition" do
      subject.push('matching-foo')
      subject.push('nonmatching-bar')
      subject.push('matching-baz')

      selected = subject.reject do |line_of_code|
        line_of_code.line.start_with?('matching')
      end
      expect(selected.lines).to eq(["nonmatching-bar\n"])
    end
  end

  describe "#between" do
    before { 4.times { |i| subject.push((i + 1).to_s) } }

    context "when start_line is nil" do
      it "returns self" do
        expect(subject.between(nil)).to eql(subject)
      end
    end

    context "when both start_line and end_line are specified" do
      it "returns a code object" do
        expect(subject.between(1)).to be_a(described_class)
      end

      it "removes all lines that aren't in the given range" do
        expect(subject.between(2, 3).lines).to eq(%W[2\n 3\n])
      end
    end

    context "when only start_line is specified" do
      it "returns a code object" do
        expect(subject.between(1)).to be_a(described_class)
      end

      it "removes leaves only the specified line" do
        expect(subject.between(2).lines).to eq(%W[2\n])
      end
    end

    context "when a negative start_line is specified" do
      it "returns a line from the end" do
        expect(subject.between(-1).lines).to eq(%W[4\n])
      end
    end

    context "when a negative end_line is specified" do
      it "returns a range of lines from the end" do
        expect(subject.between(2, -2).lines).to eq(%W[2\n 3\n])
      end
    end

    context "when start_line is a Range" do
      it "returns a range fo lines corresponding to the given Range" do
        expect(subject.between(2..3).lines).to eq(%W[2\n 3\n])
      end
    end
  end

  describe "#take_lines" do
    before { 4.times { |i| subject.push((i + 1).to_s) } }

    it "takes N lines from start_line" do
      expect(subject.take_lines(3, 2).lines).to eq(%W[3\n 4\n])
    end
  end

  describe "#before" do
    before { 4.times { |i| subject.push((i + 1).to_s) } }

    context "when line number is nil" do
      it "returns self" do
        expect(subject.before(nil)).to eql(subject)
      end
    end

    context "when line number is an integer" do
      it "selects one line before the specified line number" do
        expect(subject.before(4).lines).to eql(%W[3\n])
      end

      context "and we specify how many lines to select" do
        it "selects more than 1 line before" do
          expect(subject.before(4, 2).lines).to eql(%W[2\n 3\n])
        end
      end
    end
  end

  describe "#around" do
    before { 10.times { |i| subject.push((i + 1).to_s) } }

    context "when line number is nil" do
      it "returns self" do
        expect(subject.around(nil)).to eql(subject)
      end
    end

    context "when line number is an integer" do
      it "selects one line around the specified line number" do
        expect(subject.around(2).lines).to eql(%W[1\n 2\n 3\n])
      end

      context "and we specify how many lines to select by an integer" do
        it "selects more than 1 line around" do
          expect(subject.around(4, 2).lines).to eql(%W[2\n 3\n 4\n 5\n 6\n])
        end
      end

      context "and we specify how many lines to select by two integers" do
        it "selects before and after lines around independently" do
          expect(subject.around(4, 2, 3).lines).to eql(%W[2\n 3\n 4\n 5\n 6\n 7\n])
        end
      end
    end
  end

  describe "#after" do
    before { 4.times { |i| subject.push((i + 1).to_s) } }

    context "when line number is nil" do
      it "returns self" do
        expect(subject.after(nil)).to eql(subject)
      end
    end

    context "when line number is an integer" do
      it "selects one line around the specified line number" do
        expect(subject.after(2).lines).to eql(%W[3\n])
      end

      context "and we specify how many lines to select" do
        it "selects more than 1 line around" do
          expect(subject.after(2, 2).lines).to eql(%W[3\n 4\n])
        end
      end
    end
  end

  describe "#grep" do
    context "when pattern is nil" do
      it "returns self" do
        expect(subject.grep(nil)).to eql(subject)
      end
    end

    context "when pattern is specified" do
      subject do
        described_class.new(%w[matching-line nonmatching-line matching-line])
      end

      it "returns lines matching the pattern" do
        matching_code = subject.grep(/\Amatching/)
        expect(matching_code.lines).to eq(["matching-line\n", "matching-line\n"])
      end
    end
  end

  describe "#with_line_numbers" do
    subject { described_class.new(%w[1 2]) }

    it "appends line numbers to code" do
      code = subject.with_line_numbers(true)
      expect(code.lines).to eq(["1: 1\n", "2: 2\n"])
    end
  end

  describe "#with_marker" do
    subject { described_class.new(%w[1 2]) }

    it "shows a marker in the right place" do
      code = subject.with_marker(2)
      expect(code.lines).to eq(["    1\n", " => 2\n"])
    end
  end

  describe "#with_indentation" do
    subject { described_class.new(%w[1]) }

    it "indents lines" do
      code = subject.with_indentation(3)
      expect(code.lines).to eq(["   1\n"])
    end
  end

  describe "#max_lineno_width" do
    context "when there are less than 10 lines" do
      before { 9.times { |i| subject.push((i + 1).to_s) } }

      it "returns 1" do
        expect(subject.max_lineno_width).to eq(1)
      end
    end

    context "when there are less than 100 lines" do
      before { 99.times { |i| subject.push((i + 1).to_s) } }

      it "returns 2" do
        expect(subject.max_lineno_width).to eq(2)
      end
    end

    context "when there are less than 1000 lines" do
      before { 999.times { |i| subject.push((i + 1).to_s) } }

      it "returns 3" do
        expect(subject.max_lineno_width).to eq(3)
      end
    end
  end

  describe "#to_s" do
    subject { described_class.new(%w[1 2 3]) }

    it "returns a string representation of code" do
      expect(subject.to_s).to eq("1\n2\n3\n")
    end
  end

  describe "#highlighted" do
    subject { described_class.new(%w[1]) }

    it "returns a highlighted for terminal string representation of code" do
      expect(subject.highlighted).to eq("\e[1;34m1\e[0m\n")
    end
  end

  describe "#comment_describing" do
    subject { described_class.new(['# foo', '1']) }

    it "returns a comment describing expression" do
      expect(subject.comment_describing(2)).to eq("# foo\n")
    end
  end

  describe "#expression_at" do
    subject { described_class.new(['def foo', '  :test', 'end']) }

    it "returns a multiline expressiong starting on the given line number" do
      expect(subject.expression_at(1)).to eq("def foo\n  :test\nend\n")
    end
  end

  describe "#nesting_at" do
    subject do
      described_class.new(
        [
          'module TestModule',
          '  class TestClass',
          '    def foo',
          '      :test',
          '    end',
          '  end',
          'end'
        ]
      )
    end

    it "returns an Array of open modules" do
      expect(subject.nesting_at(5)).to eq(['module TestModule', 'class TestClass'])
    end
  end

  describe "#raw" do
    context "when code has a marker" do
      subject { described_class.new([':test']).with_marker }

      it "returns an unformatted String of all lines" do
        expect(subject.raw).to eq(":test\n")
      end
    end
  end

  describe "#length" do
    it "returns how many lines the code object has" do
      expect(subject.length).to be_zero
    end
  end

  describe "#==" do
    context "when an empty code is compared with another empty code" do
      it "returns true" do
        other_code = described_class.new
        expect(subject).to eq(other_code)
      end
    end

    context "when a code is compared with another code with identical lines" do
      subject { described_class.new(%w[line1 line2 baz]) }

      it "returns true" do
        other_code = described_class.new(%w[line1 line2 baz])
        expect(subject).to eq(other_code)
      end
    end

    context "when a code is compared with another code with different lines" do
      subject { described_class.new(%w[foo bar baz]) }

      it "returns true" do
        other_code = described_class.new(%w[bingo bango bongo])
        expect(subject).not_to eq(other_code)
      end
    end
  end

  describe "#method_missing" do
    context "when a String responds to the given method" do
      it "forwards the method to a String instance" do
        expect(subject.upcase).to eq('')
      end
    end

    context "when a String does not respond to the given method" do
      it "raises NoMethodError" do
        expect { subject.abcdefg }
          .to raise_error(NoMethodError, /undefined method `abcdefg'/)
      end
    end
  end

  describe "#respond_to_missing?" do
    context "when a String responds to the given method" do
      it "finds the method that is not defined on self" do
        expect(subject).to respond_to(:upcase)
        expect(subject.method(:upcase)).to be_a(Method)
      end
    end

    context "when a String does not respond to the given method" do
      it "doesn't find the method" do
        expect(subject).not_to respond_to(:abcdefg)
        expect { subject.method(:abcdefg) }.to raise_error(NameError)
      end
    end
  end
end
