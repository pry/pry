require_relative '../helper'

describe "exit-all" do
  before { @pry = Pry.new }

  it "should break out of the repl and return nil" do
    @pry.eval("exit-all").should equal false
    @pry.exit_value.should equal nil
  end

  it "should break out of the repl wth a user specified value" do
    @pry.eval("exit-all 'message'").should equal false
    @pry.exit_value.should == "message"
  end

  it "should break out of the repl even if multiple bindings still on stack" do
    ["cd 1", "cd 2"].each { |line| @pry.eval(line).should equal true }
    @pry.eval("exit-all 'message'").should equal false
    @pry.exit_value.should == "message"
  end

  it "should have empty binding_stack after breaking out of the repl" do
    ["cd 1", "cd 2"].each { |line| @pry.eval(line).should equal true }
    @pry.eval("exit-all").should equal false
    @pry.binding_stack.should be_empty
  end
end
