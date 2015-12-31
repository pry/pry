require 'helper'
RSpec.describe Pry::Config::Behavior do
  let(:behavior) do
    Class.new do
      include Pry::Config::Behavior
    end
  end
  
  describe "#last_default" do
    it "returns the last default in a list of defaults" do
      last = behavior.from_hash({}, nil)
      middle = behavior.from_hash({}, last)
      expect(behavior.from_hash({}, middle).last_default).to be(last)
    end
  end
end
