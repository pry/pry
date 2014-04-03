class Pry::Output < BasicObject
  ANSI_ESCAPE = /\033\[[0-9;]*m/

  def initialize(io, pry = nil)
    @pry = pry
    @io = if io.respond_to?(:wrapped_io)
      io.wrapped_io
    else
      io
    end
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
#    ::Object.method(:puts).call(m)
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
  def decolorize_maybe(*strings)
    #
    # `@pry` is typically nil if the IO being wrapped hasn't yet gone through {Pry#initialize}.
    # one place this happens is in Pry.start() if starting pry inside a critical section.
    # if an instance of `Pry` hasn't been initialized yet we assume no color.
    #
    if @pry and @pry.color
      strings.join
    else
      strings.flatten.map { |str|
        str.gsub(ANSI_ESCAPE, '')
      }.join
    end
  end
end
