# frozen_string_literal: true

RSpec.describe Pry::Config::MemoizedValue do
  describe "#call" do
    it "memoizes the result of call" do
      instance = described_class.new { rand }
      expect(instance.call).to eq(instance.call)
    end

    it "doesn't conflate falsiness with unmemoizedness" do
      count = 0
      instance = described_class.new do
        count += 1
        nil
      end
      expect(instance.call).to eq nil
      expect(instance.call).to eq nil
      expect(count).to eq 1
    end
  end
end
