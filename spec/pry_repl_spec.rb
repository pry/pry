require 'helper'

describe "The REPL" do
  before do
    Pry.config.auto_indent = true
  end

  after do
    Pry.config.auto_indent = false
  end

  it "should let you run commands in the middle of multiline expressions" do
    mock_pry("def a", "!", "5").should =~ /Input buffer cleared/
  end
end
