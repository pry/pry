require_relative 'helper'
RSpec.describe Pry::Deprecate do

  let(:t) do
    PryTester.new binding
  end

  let(:pry) do
    t.pry
  end

  before do
    pry.config.print_deprecations = true
  end

  context do
    before do
      pry.h.deprecate_method! ["String#+"], "Use #<< instead"
    end

    specify "prints deprecation message after a deprecated method is called" do
      t.eval("String.new + '1'")
      expect(t.out.string).to include('DEPRECATED  Use #<< instead')
    end

    specify "includes location of caller" do
      t.eval("String.new + '1'")
      expect(t.out.string).to include(".. Called from (pry):2")
    end

    specify "includes instructions to toggle deprecation messages" do
      t.eval("String.new + '1'")
      expect(t.out.string).to include(%q(Run 'toggle-pry-deprecations' or '_pry_.config.print_deprecations = false' to stop printing this message))
    end

    specify "disable-able" do
      pry.config.print_deprecations = false
      t.eval("String.new + '1'")
      expect(t.out.string).to eq("")
    end
  end
end
