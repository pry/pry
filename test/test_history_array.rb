require 'helper'

class Pry
  # A history array is an array to which you can only add elements. Older
  # entries are removed progressively, so that the aray never contains more than
  # N elements.
  #
  # @example
  #   ary = Pry::HistoryArray.new 10
  #   ary << 1 << 2 << 3
  #   ary[0] # => 1
  #   ary[1] # => 2
  #   10.times { |n| ary << n }
  #   ary[0] # => nil
  #   ary[-1] # => 9
  class HistoryArray
    include Enumerable

    # @param [Integer] size Maximum amount of objects in the array
    def initialize(size)
      @max_size = size

      @hash  = {}
      @count = 0
    end

    # Pushes an object at the end of the array
    # @param [Object] value Object to be added
    def <<(value)
      @hash[@count] = value

      if @hash.size > max_size
        @hash.delete(@count - max_size)
      end

      @count += 1

      self
    end

    # @overload [](index)
    #   @param [Integer] index Index of the item to access.
    #   @return [Object, nil] Item at that index or nil if it has been removed.
    # @overload [](index, size)
    #   @param [Integer] index Index of the first item to access.
    #   @param [Integer] size Amount of items to access
    #   @return [Array, nil] The selected items. Nil if index is greater than
    #     the size of the array.
    # @overload [](range)
    #   @param [Range<Integer>] range Range of indices to access.
    #   @return [Array, nil] The selected items. Nil if index is greater than
    #     the size of the array.
    def [](index_or_range, size = nil)
      if index_or_range.is_a? Integer
        index = convert_index(index_or_range)

        if size
          end_index = index + size
          index > @count ? nil : (index...[end_index, @count].min).map do |n|
            @hash[n]
          end
        else
          @hash[index]
        end
      else
        range = convert_range(index_or_range)
        range.begin > @count ? nil : range.map { |n| @hash[n] }
      end
    end

    # @return [Integer] Amount of objects in the array
    def size
      @count
    end

    def each
      ((@count - size)...@count).each do |n|
        yield @hash[n]
      end
    end

    def to_a
      ((@count - size)...@count).map { |n| @hash[n] }
    end

    def inspect
      to_a.inspect
    end

    # @return [Integer] Maximum amount of objects in the array
    attr_reader :max_size

    private
    def convert_index(n)
      n >= 0 ? n : @count + n
    end

    def convert_range(range)
      end_index = convert_index(range.end)
      end_index += 1 unless range.exclude_end?

      Range.new(convert_index(range.begin), [end_index, @count].min, true)
    end
  end
end

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
