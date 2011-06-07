require 'helper'

describe Pry::HistoryArray do
  before do
    @array = Pry::HistoryArray.new 10
  end

  it 'should have a maximum size specifed at creation time' do
    @array.max_size.should == 10
  end

  it 'should be able to be added objects to' do
    @array << 1 << 2 << 3
    @array.size.should == 3
    @array.to_a.should == [1, 2, 3]
  end

  it 'should be able to access single elements' do
    @array << 1 << 2 << 3
    @array[2].should == 3
  end

  it 'should be able to access negative indices' do
    @array << 1 << 2 << 3
    @array[-1].should == 3
  end

  it 'should be able to access ranges' do
    @array << 1 << 2 << 3 << 4
    @array[1..2].should == [2, 3]
  end

  it 'should be able to access ranges starting from a negative index' do
    @array << 1 << 2 << 3 << 4
    @array[-2..3].should == [3, 4]
  end

  it 'should be able to access ranges ending at a negative index' do
    @array << 1 << 2 << 3 << 4
    @array[2..-1].should == [3, 4]
  end

  it 'should be able to access ranges using only negative indices' do
    @array << 1 << 2 << 3 << 4
    @array[-2..-1].should == [3, 4]
  end

  it 'should be able to use range where end is excluded' do
    @array << 1 << 2 << 3 << 4
    @array[-2...-1].should == [3]
  end

  it 'should be able to access slices using a size' do
    @array << 1 << 2 << 3 << 4
    @array[-3, 2].should == [2, 3]
  end

  it 'should remove older entries' do
    11.times { |n| @array << n }

    @array[0].should  == nil
    @array[1].should  == 1
    @array[10].should == 10
  end
end
