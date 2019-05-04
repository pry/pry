RSpec.describe Pry::Warning do
  describe "#warn" do
    it "prints a warning with file and line" do
      expect(Kernel).to receive(:warn).with(
        "#{__FILE__}:#{__LINE__ + 2}: warning: foo bar"
      )
      described_class.warn('foo bar')
    end
  end
end
