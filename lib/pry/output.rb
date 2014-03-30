class Pry::Output < BasicObject
  # courtesy of:
  # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
  SHELL_COLOR_REGEXP = /\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]/

  def initialize(io, pry = nil)
    @io = io
    @pry = pry
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

  def wrapped_io?
    true
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
        str.gsub(SHELL_COLOR_REGEXP, '')
      }.join
    end
  end
end
