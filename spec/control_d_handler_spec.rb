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
        instance = nil
        redirect_pry_io(InputTester.new(@control_d)) do
          instance = Pry.new
          instance.repl
        end

        instance.binding_stack.should.be.empty
      end
    end

    describe 'in a nested session' do
      it 'should pop last binding from the binding stack' do
        base = OpenStruct.new
        base.obj = OpenStruct.new

        redirect_pry_io(InputTester.new("cd obj", "self.stack_size = _pry_.binding_stack.size",
                                        @control_d, "self.stack_size = _pry_.binding_stack.size", "exit-all")) do
          Pry.start(base)
        end

        base.obj.stack_size.should == 2
        base.stack_size.should == 1
      end
    end
  end
end
