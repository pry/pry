RSpec.describe Pry::Config::Behavior do
  let(:behavior) do
    Class.new do
      include Pry::Config::Behavior
    end
  end

  describe "#last_default" do
    it "returns the last default" do
      last = behavior.from_hash({}, nil)
      middle = behavior.from_hash({}, last)
      expect(behavior.from_hash({}, middle).last_default).to be(last)
    end
  end

  describe "#eager_load!" do
    it "returns nil when the default is nil" do
      expect(behavior.from_hash({}, nil).eager_load!).to be(nil)
    end
  end
end
