# frozen_string_literal: true

RSpec.describe Pry::Warning do
  describe "#warn" do
    it "prints message with file and line of the calling frame" do
      expect(Kernel).to receive(:warn).with(/.+\.rb:\d+: warning: foo bar/)
      described_class.warn('foo bar')
    end
  end
end
