# frozen_string_literal: true

RSpec.describe Pry::Config::MemoizedValue do
  describe "#call" do
    subject { described_class.new { rand } }

    it "memoizes the result of call" do
      expect(subject.call).to eq(subject.call)
    end
  end
end
