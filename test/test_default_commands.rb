require 'helper'

describe Pry::Commands do
  describe "cd" do
    it 'should cd into simple input' do
      str_output = StringIO.new
      b = Pry.binding_for(Object.new)
      b.eval("x = :mon_ouie")

      redirect_global_pry_input(InputTester.new("cd x", "self.should == :mon_ouie;", "exit-all")) do
        Pry.new(:output => str_output).rep(b)
      end

    end

    it 'should cd into complex input (with spaces)' do
      str_output = StringIO.new
      o = Object.new
      def o.hello(x, y, z)
        :mon_ouie
      end

      redirect_global_pry_input(InputTester.new("cd hello 1, 2, 3", "exit-all")) do
        Pry.new(:output => str_output).rep(o)
      end

      str_output.string.should  =~ /:mon_ouie/
    end
  end
end
