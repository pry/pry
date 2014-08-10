require_relative '../helper'

describe "exit" do
  before { @pry = Pry.new(:target => :outer, :output => StringIO.new) }

  it "should pop a binding" do
    @pry.eval "cd :inner"
    @pry.evaluate_ruby("self").should == :inner
    @pry.eval "exit"
    @pry.evaluate_ruby("self").should == :outer
  end

  it "should break out of the repl when binding_stack has only one binding" do
    @pry.eval("exit").should equal false
    @pry.exit_value.should equal nil
  end

  it "should break out of the repl and return user-given value" do
    @pry.eval("exit :john").should equal false
    @pry.exit_value.should == :john
  end

  it "should break out of the repl even after an exception" do
    @pry.eval "exit = 42"
    @pry.output.string.should =~ /^SyntaxError/
    @pry.eval("exit").should equal false
  end
end
