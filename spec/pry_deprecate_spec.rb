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

    specify "deprecations vanish once the repl exits" do
      io = StringIO.new
      pry.h.deprecate_method! [io.method(:puts)], "salmon is tasty but trout is delicious"
      # Manual simulation of exit is required, since hooks don't naturally run
      # in test environment. It's a FIXME.
      pry.eval("exit")
      pry.hooks.exec_hook(:after_session)
      io.puts ""
      expect(pry.output.string).to_not include("salmon is tasty but trout is delicious")
    end

    specify "deprecated method is bound to a new self, at every call" do
      io = StringIO.new
      pry.h.deprecate_method! [io.method(:puts)], "trout is delicious"
      io2 = StringIO.new
      io2.puts "foo"
      expect(io2.string).to eq("foo\n")
    end
  end
end
