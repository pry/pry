require 'helper'

describe Pry::DEFAULT_CONTROL_D_HANDLER do

  describe "control-d press" do

    before do
      # Simulates a ^D press.
      @control_d = "Pry::DEFAULT_CONTROL_D_HANDLER.call('', _pry_)"
    end

    describe "in an expression" do
      it "should clear out passed string" do
        str = 'hello world'
        Pry::DEFAULT_CONTROL_D_HANDLER.call(str, nil)
        str.should == ''
      end
    end


    describe "at top-level session" do
      it "breaks out of a REPL" do
        pry_tester(0).simulate_repl do |t|
          t.eval @control_d
        end.should == nil
      end
    end

    describe "in a nested session" do
      it "pops last binding from the binding stack" do
        pry_tester(0).simulate_repl { |t|
          t.eval 'cd :foo'
          t.eval('_pry_.binding_stack.size').should == 2
          t.eval(@control_d)
          t.eval('_pry_.binding_stack.size').should == 1
          t.eval 'exit-all'
        }
      end

      it "breaks out of the parent session" do
        pry_tester(:outer).simulate_repl do |o|
          o.context = :inner
          o.simulate_repl { |i|
            i.eval('_pry_.current_context.eval("self")').should == :inner
            i.eval('_pry_.binding_stack.size').should == 2
            i.eval @control_d
            i.eval('_pry_.binding_stack.size').should == 1
            i.eval('_pry_.current_context.eval("self")').should == :outer
            i.eval 'throw :breakout'
          }
          o.eval 'exit-all'
        end
      end
    end

  end

end
