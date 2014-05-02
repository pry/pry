class Pry::BStack < BasicObject 
  SIDEWAYS = " / "

  def initialize(pry)
    @stack = []
    @pry = pry
    @index = 0
  end

  def method_missing(m, *argz, &blk)
    @stack.public_send(m, *argz, &blk)
  end

  def switch_to(index)
    ::Kernel.raise ::IndexError, "index is out of bounds" if index >= @stack.size
    @index = index
  end

  def to_s
    path = @stack.map { |b| ::Pry.view_clip(b) }.join(SIDEWAYS)
    "[%s] %s %s " % [@pry.input_array.size, @pry.config.prompt_name, path]
  end
end