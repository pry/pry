require 'helper'

describe Pry::DEFAULT_CONTROL_D_HANDLER do
  describe 'control-d press' do
    before do
      @control_d = "Pry::DEFAULT_CONTROL_D_HANDLER.call('', _pry_)"
      @binding_stack = "$binding_stack = _pry_.binding_stack.dup"
    end

    #describe 'in an expression' do
      #it 'should clear input buffer' do
      #end
    #end

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
        $obj = Object.new
        $obj.instance_variable_set(:@x, :mon_dogg)
        $obj.instance_variable_set(:@y, :john_dogg)

        redirect_pry_io(InputTester.new("cd $obj", @control_d,
                                        @binding_stack, "exit-all")) do
          Pry.start
        end

        $binding_stack.size.should == 1
        $binding_stack.last.eval("self") == TOPLEVEL_BINDING.eval("self")

        redirect_pry_io(InputTester.new("cd $obj/@x", "cd $obj/@y",
                                        "cd 42", @control_d, @binding_stack,
                                        "exit-all")) do
          Pry.start
        end

        $binding_stack.size.should == 5
        $binding_stack.last.eval("self") == :john_dogg

        redirect_pry_io(InputTester.new("cd $obj/@x", "cd $obj/@y", "cd 42",
                                        @control_d, @control_d, @control_d,
                                        @binding_stack, "exit-all")) do
          Pry.start
        end

        $binding_stack.size.should == 3
        $binding_stack.last.eval("self") == :mon_dogg
      end
    end
  end
end
