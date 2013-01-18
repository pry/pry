require 'helper'

describe "exit-all" do
  before { @pry = Pry.new }

  it "should break out of the repl and return nil" do
    @pry.eval("exit-all").should.be.false
    @pry.exit_value.should.be.nil
  end

  it "should break out of the repl wth a user specified value" do
    @pry.eval("exit-all 'message'").should.be.false
    @pry.exit_value.should == "message"
  end

  it "should break out of the repl even if multiple bindings still on stack" do
    ["cd 1", "cd 2"].each { |line| @pry.eval(line).should.be.true }
    @pry.eval("exit-all 'message'").should.be.false
    @pry.exit_value.should == "message"
  end

  it "should have empty binding_stack after breaking out of the repl" do
    ["cd 1", "cd 2"].each { |line| @pry.eval(line).should.be.true }
    @pry.eval("exit-all").should.be.false
    @pry.binding_stack.should.be.empty
  end
end
