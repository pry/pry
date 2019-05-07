# frozen_string_literal: true

describe "exit" do
  before { @pry = Pry.new(target: :outer, output: StringIO.new) }

  it "should pop a binding" do
    @pry.eval "cd :inner"
    expect(@pry.evaluate_ruby("self")).to eq :inner
    @pry.eval "exit"
    expect(@pry.evaluate_ruby("self")).to eq :outer
  end

  it "should break out of the repl when binding_stack has only one binding" do
    expect(@pry.eval("exit")).to equal false
    expect(@pry.exit_value).to equal nil
  end

  it "should break out of the repl and return user-given value" do
    expect(@pry.eval("exit :john")).to equal false
    expect(@pry.exit_value).to eq :john
  end

  it "should break out of the repl even after an exception" do
    @pry.eval "exit = 42"
    expect(@pry.output.string).to match(/^SyntaxError/)
    expect(@pry.eval("exit")).to equal false
  end
end
