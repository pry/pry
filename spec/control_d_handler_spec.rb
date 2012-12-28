require 'helper'

describe Pry::DEFAULT_CONTROL_D_HANDLER do
  describe 'control-d press' do
    before do
      @control_d = "Pry::DEFAULT_CONTROL_D_HANDLER.call('', _pry_)"
      @binding_stack = "self.binding_stack = _pry_.binding_stack.dup"
    end

   describe 'in an expression' do
      it 'should clear out passed string' do
        str = "hello world"
        Pry::DEFAULT_CONTROL_D_HANDLER.call(str, nil)
        str.should == ""
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
    end
  end
end
