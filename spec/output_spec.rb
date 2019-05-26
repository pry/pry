# frozen_string_literal: true

RSpec.describe Pry::Output do
  let(:output) { StringIO.new }
  let(:pry_instance) { Pry.new(output: output) }

  subject { described_class.new(pry_instance) }

  describe "#puts" do
    it "returns nil" do
      expect(subject.puts).to be_nil
    end

    context "when given an empty array" do
      it "prints a newline" do
        subject.puts([])
        expect(output.string).to eq("\n")
      end
    end

    context "when given multiple empty arrays" do
      it "prints multiple newline" do
        subject.puts([], [], [])
        expect(output.string).to eq("\n\n\n")
      end
    end

    context "when given convertible to array objects" do
      let(:obj) do
        Object.new.tap { |o| o.define_singleton_method(:to_ary) { [1] } }
      end

      let(:other_obj) do
        Object.new.tap { |o| o.define_singleton_method(:to_ary) { [2] } }
      end

      it "prints the converted objects" do
        subject.puts([obj, other_obj])
        expect(output.string).to eq("1\n2\n")
      end
    end

    context "when given non-convertible to array objects" do
      let(:obj) { Object.new }
      let(:other_obj) { Object.new }

      it "prints the non-converted objects in its string form" do
        subject.puts([obj, other_obj])
        expect(output.string).to match(/\A#<Object:.+>\n#<Object:.+>\n\z/)
      end

      context "and when the object's #to_s has a newline" do
        let(:obj) do
          Object.new.tap { |o| o.define_singleton_method(:to_s) { "abc\n" } }
        end

        it "doesn't print a double newline" do
          subject.puts(obj)
          expect(output.string).to eq("abc\n")
        end
      end
    end

    context "when the given pry instance has 'color' enabled" do
      let(:pry_instance) { Pry.new(output: output, color: true) }

      it "doesn't decolorize output" do
        subject.puts("\e[30mhi\e[0m")
        expect(output.string).to eq("\e[30mhi\e[0m\n")
      end
    end

    context "when the given pry instance has 'color' disabled" do
      let(:pry_instance) { Pry.new(output: output, color: false) }

      it "decolorizes output" do
        subject.puts("\e[30mhi\e[0m")
        expect(output.string).to eq("hi\n")
      end
    end
  end

  describe "#print" do
    it "returns nil" do
      expect(subject.print).to be_nil
    end

    context "when the given pry instance has 'color' enabled" do
      let(:pry_instance) { Pry.new(output: output, color: true) }

      it "doesn't decolorize output" do
        subject.print("\e[30mhi\e[0m")
        expect(output.string).to eq("\e[30mhi\e[0m")
      end
    end

    context "when the given pry instance has 'color' disabled" do
      let(:pry_instance) { Pry.new(output: output, color: false) }

      it "decolorizes output" do
        subject.print("\e[30mhi\e[0m")
        expect(output.string).to eq('hi')
      end
    end
  end

  describe "#<<" do
    specify { expect(subject.method(:<<)).to eq(subject.method(:print)) }
  end

  describe "#write" do
    specify { expect(subject.method(:write)).to eq(subject.method(:print)) }
  end

  describe "#tty?" do
    context "when the output responds to #tty? and is a TTY" do
      before { expect(output).to receive(:tty?).and_return(true) }

      it "returns true" do
        expect(subject).to be_tty
      end
    end

    context "when the output responds to #tty? and is not a TTY" do
      before do
        expect(output).to receive(:respond_to?).with(:tty?).and_return(true)
        expect(output).to receive(:tty?).and_return(false)
      end

      it "returns false" do
        expect(subject).not_to be_tty
      end
    end

    context "when the output doesn't respond to #tty?" do
      before do
        expect(output).to receive(:respond_to?).with(:tty?).and_return(false)
      end

      it "returns false" do
        expect(subject).not_to be_tty
      end
    end
  end

  describe "#method_missing" do
    context "when the output responds to the given method name" do
      it "forwards the method to the output" do
        expect(output).to receive(:abcd)
        subject.abcd
      end
    end

    context "when the output doesn't respond to the given method name" do
      it "raises NoMethodError" do
        expect { subject.abcd }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#respond_to_missing?" do
    context "when the output responds to the given method name" do
      before { output.define_singleton_method(:test_method) {} }

      it "finds the method that is not defined on self" do
        expect(subject).to respond_to(:test_method)
        expect(subject.method(:test_method)).to be_a(Method)
      end
    end

    context "when the output doesn't respond to the given method name" do
      it "doesn't find the method" do
        expect(subject).not_to respond_to(:test_method)
        expect { subject.method(:test_method) }.to raise_error(NameError)
      end
    end
  end

  describe "#decolorize_maybe" do
    context "when the given pry instance has 'color' enabled" do
      let(:pry_instance) { Pry.new(output: output, color: true) }

      it "returns the given string without modifications" do
        str = "\e[30mhi\e[0m"
        expect(subject.decolorize_maybe(str)).to eql(str)
      end
    end

    context "when the given pry instance has 'color' disabled" do
      let(:pry_instance) { Pry.new(output: output, color: false) }

      it "returns decolorized string" do
        expect(subject.decolorize_maybe("\e[30mhi\e[0m")).to eq('hi')
      end
    end
  end
end
