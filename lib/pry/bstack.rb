class Pry::BStack < BasicObject 
  def initialize(pry)
    @stack = []
    @pry = pry
    @index = 0
  end

  def switch_to(index)
    ::Kernel.raise ::IndexError, "index is out of bounds" if index >= @stack.size
    @index = index
  end

  def method_missing(m, *argz, &blk)
    @stack.public_send(m, *argz, &blk)
  end
end