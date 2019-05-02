# frozen_string_literal: true

RSpec.describe "jump-to" do
  let(:obj) { Object.new }

  it 'jumps to the proper binding index in the stack' do
    expect(pry_eval(obj, "cd 1", "cd 2", "jump-to 0", 'self')).to eq obj
    expect(pry_eval(obj, 'cd 1', 'cd 2', 'jump-to 1', 'self')).to eq 1
  end

  it 'prints an error when trying to jump to the same binding index' do
    expect(pry_eval(obj, "cd 1", "cd 2", "jump-to 2")).to match(/Already/)
  end

  it 'prints error when trying to jump to a non-existent binding index' do
    expect(pry_eval(obj, "cd 1", "cd 2", "jump-to 3")).to match(/Invalid nest level/)
  end
end
