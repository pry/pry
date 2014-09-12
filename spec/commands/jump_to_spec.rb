require_relative '../helper'

describe "jump-to" do
  it 'should jump to the proper binding index in the stack' do
    expect(pry_eval('cd 1', 'cd 2', 'jump-to 1', 'self')).to eq(1)
  end

  it 'should print error when trying to jump to a non-existent binding index' do
    expect(pry_eval("cd 1", "cd 2", "jump-to 100")).to match(/Invalid nest level/)
  end

  it 'should print error when trying to jump to the same binding index' do
    expect(pry_eval("cd 1", "cd 2", "jump-to 2")).to match(/Already/)
  end
end
