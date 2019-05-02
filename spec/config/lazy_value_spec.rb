# frozen_string_literal: true

RSpec.describe Pry::Config::LazyValue do
  describe "#call" do
    subject { described_class.new { rand } }

    it "doesn't memoize the result of call" do
      expect(subject.call).not_to eq(subject.call)
    end
  end
end
