require 'helper'

describe "exit-all" do
  it 'should break out of the repl loop of Pry instance and return nil' do
    pry_tester(0).simulate_repl do |t|
      t.eval 'exit-all'
    end.should == nil
  end

  it 'should break out of the repl loop of Pry instance wth a user specified value' do
    pry_tester(0).simulate_repl do |t|
      t.eval "exit-all 'message'"
    end.should == 'message'
  end

  it 'should break of the repl loop even if multiple bindings still on stack' do
    pry_tester(0).simulate_repl do |t|
      t.eval 'cd 1', 'cd 2', "exit-all 'message'"
    end.should == 'message'
  end

  it 'binding_stack should be empty after breaking out of the repl loop' do
    t = pry_tester(0) do
      def binding_stack
        @pry.binding_stack
      end
    end

    t.simulate_repl do |t|
      t.eval 'cd 1', 'cd 2', 'exit-all'
    end
    t.binding_stack.empty?.should == true
  end
end
