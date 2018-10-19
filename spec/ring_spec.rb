require_relative 'helper'

describe Pry::Ring do
  before do
    @ring = Pry::Ring.new(10)
    @populated = @ring.dup << 1 << 2 << 3 << 4
  end

  it 'should have a maximum size specifed at creation time' do
    expect(@ring.max_size).to eq 10
  end

  it 'should be able to be added objects to' do
    expect(@populated.size).to eq 4
    expect(@populated.to_a).to eq [1, 2, 3, 4]
  end

  it 'should be able to access single elements' do
    expect(@populated[2]).to eq 3
  end

  it 'should be able to access negative indices' do
    expect(@populated[-1]).to eq 4
  end

  it 'should be able to access ranges' do
    expect(@populated[1..2]).to eq [2, 3]
  end

  it 'should be able to access ranges starting from a negative index' do
    expect(@populated[-2..3]).to eq [3, 4]
  end

  it 'should be able to access ranges ending at a negative index' do
    expect(@populated[2..-1]).to eq [3, 4]
  end

  it 'should be able to access ranges using only negative indices' do
    expect(@populated[-2..-1]).to eq [3, 4]
  end

  it 'should be able to use range where end is excluded' do
    expect(@populated[-2...-1]).to eq [3]
  end

  it 'should be able to access slices using a size' do
    expect(@populated[-3, 2]).to eq [2, 3]
  end

  it 'should remove older entries' do
    11.times { |n| @ring << n }

    expect(@ring[0]).to  eq nil
    expect(@ring[1]).to  eq 1
    expect(@ring[10]).to eq 10
  end

  it 'should not be larger than specified maximum size' do
    12.times { |n| @ring << n }
    expect(@ring.entries.compact.size).to eq 10
  end

  it 'should pop!' do
    @populated.pop!
    expect(@populated.to_a).to eq [1, 2, 3]
  end

  it 'should return an indexed hash' do
    expect(@populated.to_h[0]).to eq @populated[0]
  end
end
