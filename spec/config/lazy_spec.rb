require 'helper'
RSpec.describe Pry::Config::Lazy do
  let(:lazyobject) do
    Class.new do
      include Pry::Config::Lazy
      lazy_implement({foo: proc {"bar"}})
    end.new
  end

  it 'memorizes value after first call' do
    expect(lazyobject.foo).to equal(lazyobject.foo)
  end
end
