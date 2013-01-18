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

    describe 'at top-level session' do
      it 'should break out of a REPL loop' do
        instance = Pry.new
        instance.binding_stack.should.not.be.empty
        instance.eval(nil).should.be.false
        instance.binding_stack.should.be.empty
      end
    end

    describe 'in a nested session' do
      it 'should pop last binding from the binding stack' do
        t = pry_tester
        t.eval "cd Object.new"
        t.eval("_pry_.binding_stack.size").should == 2
        t.eval("_pry_.eval(nil)").should.be.true
        t.eval("_pry_.binding_stack.size").should == 1
      end

      it "breaks out of the parent session" do
        ReplTester.start do
          input  'Pry::REPL.new(_pry_, :target => 10).start'
          output ''
          prompt(/10.*> $/)

          input  'self'
          output '=> 10'

          input  nil # Ctrl-D
          output ''

          input  'self'
          output '=> main'

          input  nil # Ctrl-D
          output '=> nil' # Exit value of nested REPL.
          assert_exited
        end
      end
    end

  end

end
