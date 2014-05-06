class Pry::BStack < BasicObject 
  SIDEWAYS      = " / "
  SPLIT_R       = %r(/)
  EMPTY_STACK   = [].freeze

  def initialize(pry)
    @stack = EMPTY_STACK
    @pry = pry
    @people = 0
  end

  def method_missing(m, *argz, &blk)
    @stack.public_send(m, *argz, &blk)
  end

  def switch_to(index)
    ::Kernel.raise ::IndexError, "index is out of bounds" if index >= @stack.size
    @people = index
  end

  def last
    @stack.last
  end

  def frozen?
    @stack.frozen?
  end

  def push(b)
    if frozen?
      @stack = [] 
    end
    @stack.push(b)
  end
 
  def eval(str)
    ::Kernel.eval ::Kernel.inspect(str), last
  end

  def bump_index!
    @people += 1
  end
    
  def traverse_via(str)
    case str
    when "-"
      @stack = EMPTY_STACK
    when SPLIT_R
      str.scan(SPLIT_R) { |f| f == ".." ? @stack.pop : @stack.push(eval(f)) }
    else
      eval(str)
    end
  end

  def inspect(*)
    path = @stack.map { |b| ::Pry.view_clip(b) }.join(SIDEWAYS)
    "[%s] %s %s " % [@pry.input_array.size, @pry.config.prompt_name, path]
  end
end