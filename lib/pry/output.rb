class Pry::Output < BasicObject
  ANSI_ESCAPE = /\033\[[0-9;]*m/

  def initialize(io, pry = nil)
    @pry = pry
    @io = io.respond_to?(:wrapped_io) ? io.wrapped_io : io
  end

  def <<(string)
    @io << decolorize_maybe(string)
  end

  def write(string)
    @io.write decolorize_maybe(string)
  end

  def print(*strings)
    @io.print decolorize_maybe(*strings)
  end

  def puts(*strings)
    @io.puts decolorize_maybe(*strings)
  end

  def pretty_print(string)
    @io.pretty_print decolorize_maybe(string)
  end

  def flush
    @io.flush
  end

  def method_missing(m, *args, &block)
    if @io.respond_to?(m)
      @io.public_send(m, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(m, include_private = false)
    @io.respond_to?(m, false)
  end

  def unwrapped_io
    @io
  end

private
  def decolorize_maybe(str)
    #
    # `@pry` is typically nil if the IO being wrapped hasn't yet gone through {Pry#initialize}.
    # one place this happens is in Pry.start() if starting pry inside a critical section.
    # if an instance of `Pry` hasn't been initialized yet we assume no color.
    #
    if @pry and @pry.color
      str.kind_of?(Array) ? str.join : str
    else
      str.map { |s| s.gsub(ANSI_ESCAPE, '') }
    end
  end
end
