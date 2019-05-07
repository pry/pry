# frozen_string_literal: true

describe "exit-all" do
  before { @pry = Pry.new }

  it "should break out of the repl and return nil" do
    expect(@pry.eval("exit-all")).to equal false
    expect(@pry.exit_value).to equal nil
  end

  it "should break out of the repl wth a user specified value" do
    expect(@pry.eval("exit-all 'message'")).to equal false
    expect(@pry.exit_value).to eq("message")
  end

  it "should break out of the repl even if multiple bindings still on stack" do
    ["cd 1", "cd 2"].each { |line| expect(@pry.eval(line)).to equal true }
    expect(@pry.eval("exit-all 'message'")).to equal false
    expect(@pry.exit_value).to eq("message")
  end

  it "should have empty binding_stack after breaking out of the repl" do
    ["cd 1", "cd 2"].each { |line| expect(@pry.eval(line)).to equal true }
    expect(@pry.eval("exit-all")).to equal false
    expect(@pry.binding_stack).to be_empty
  end
end
