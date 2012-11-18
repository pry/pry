require 'helper'

describe Pry::HistoryArray do
  before do
    @array = Pry::HistoryArray.new 10
    @populated = @array.dup << 1 << 2 << 3 << 4
  end

  it 'should have a maximum size specifed at creation time' do
    @array.max_size.should == 10
  end

  it 'should be able to be added objects to' do
    @populated.size.should == 4
    @populated.to_a.should == [1, 2, 3, 4]
  end

  it 'should be able to access single elements' do
    @populated[2].should == 3
  end

  it 'should be able to access negative indices' do
    @populated[-1].should == 4
  end

  it 'should be able to access ranges' do
    @populated[1..2].should == [2, 3]
  end

  it 'should be able to access ranges starting from a negative index' do
    @populated[-2..3].should == [3, 4]
  end

  it 'should be able to access ranges ending at a negative index' do
    @populated[2..-1].should == [3, 4]
  end

  it 'should be able to access ranges using only negative indices' do
    @populated[-2..-1].should == [3, 4]
  end

  it 'should be able to use range where end is excluded' do
    @populated[-2...-1].should == [3]
  end

  it 'should be able to access slices using a size' do
    @populated[-3, 2].should == [2, 3]
  end

  it 'should remove older entries' do
    11.times { |n| @array << n }

    @array[0].should  == nil
    @array[1].should  == 1
    @array[10].should == 10
  end

  it 'should not be larger than specified maximum size' do
    12.times { |n| @array << n }
    @array.entries.compact.size.should == 10
  end

  it 'should pop!' do
    @populated.pop!
    @populated.to_a.should == [1, 2, 3]
  end
end
