# frozen_string_literal: true

RSpec.describe Pry::Config::Value do
  describe "#call" do
    context "when given value is a MemoizedValue" do
      subject { described_class.new(Pry::Config::MemoizedValue.new { 123 }) }

      it "calls the MemoizedLazy object" do
        expect(subject.call).to eq(123)
      end
    end

    context "when given value is a LazyValue" do
      subject { described_class.new(Pry::Config::LazyValue.new { 123 }) }

      it "calls the LazyValue object" do
        expect(subject.call).to eq(123)
      end
    end

    context "when given value is a Proc" do
      let(:callable) { proc {} }

      subject { described_class.new(callable) }

      it "returns the value as is" do
        expect(subject.call).to eq(callable)
      end
    end

    context "when given value is a non-callable object" do
      subject { described_class.new('test') }

      it "returns the value as is" do
        expect(subject.call).to eq('test')
      end
    end
  end
end
