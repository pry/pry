require 'helper'
RSpec.describe Pry::Config::Lazy do
  let(:lazyobj) do
    Class.new do
      include Pry::Config::Lazy
      lazy_implement({foo: proc {"foo"}, bar: proc {"bar"}})
    end.new
  end

  describe "on call of a lazy method" do
    it "memoizes the return value" do
      expect(lazyobj.foo).to be(lazyobj.foo)
    end
  end

  describe "#lazy_keys" do
    it "tracks a list of lazy keys" do
      expect(lazyobj.lazy_keys).to eq([:foo, :bar])
    end
  end
end
