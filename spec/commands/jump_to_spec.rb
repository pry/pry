require 'helper'

describe "jump-to" do
  it 'should jump to the proper binding index in the stack' do
    pry_eval('cd 1', 'cd 2', 'jump-to 1', 'self').should == 1
  end

  it 'should print error when trying to jump to a non-existent binding index' do
    pry_eval("cd 1", "cd 2", "jump-to 100").should =~ /Invalid nest level/
  end

  it 'should print error when trying to jump to the same binding index' do
    pry_eval("cd 1", "cd 2", "jump-to 2").should =~ /Already/
  end
end
