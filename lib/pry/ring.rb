class Pry
  # A ring is an array to which you can only add elements. Older entries are
  # removed progressively, so that the array never contains more than N
  # elements.
  #
  # Rings are used by Pry to store the output of the last commands.
  #
  # @example
  #   ring = Pry::Ring.new(10)
  #   ring << 1 << 2 << 3
  #   ring[0] # => 1
  #   ring[1] # => 2
  #   10.times { |n| ring << n }
  #   ring[0] # => nil
  #   ring[-1] # => 9
  class Ring
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
      unless index_or_range.is_a?(Integer)
        range = convert_range(index_or_range)
        return range.begin > @count ? nil : range.map { |n| @hash[n] }
      end

      index = convert_index(index_or_range)
      return @hash[index] unless size
      return if index > @count

      end_index = index + size
      (index...[end_index, @count].min).map { |n| @hash[n] }
    end

    # @return [Integer] Amount of objects in the array
    def size
      @count
    end
    alias count size
    alias length size

    def empty?
      size == 0
    end

    def each
      ((@count - size)...@count).each do |n|
        yield @hash[n]
      end
    end

    def to_a
      ((@count - size)...@count).map { |n| @hash[n] }
    end

    # @return [Hash] copy of the internal @hash history
    def to_h
      @hash.dup
    end

    def pop!
      @hash.delete @count - 1
      @count -= 1
    end

    def inspect
      "#<#{self.class} size=#{size} first=#{@count - size} max_size=#{max_size}>"
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
