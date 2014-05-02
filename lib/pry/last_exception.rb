#
# {Pry::LastException} is a proxy class who wraps an Exception object for
# {Pry#last_exception}. it extends the exception object with methods that
# help pry commands be useful.
#
# the original exception object is not modified and method calls are forwarded
# to the wrapped exception object.
#
class Pry::LastException < BasicObject
  attr_accessor :bt_index

  def initialize(e)
    @e = e
    @bt_index = 0
    @file, @line = bt_source_location_for(0)
  end

  def method_missing(name, *args, &block)
    if @e.respond_to?(name)
      @e.public_send(name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    @e.respond_to?(name)
  end

  #
  # @return [String]
  #  returns the path to a file for the current backtrace. see {#bt_index}.
  #
  def file
    @file
  end

  #
  # @return [Fixnum]
  #  returns the line for the current backtrace. see {#bt_index}.
  #
  def line
    @line
  end
  
  #
  # @return [Exception]
  #   returns the wrapped exception
  #
  def wrapped_exception
    @e
  end

  #
  #  bumps the internal index that tracks the position in 
  #  the backtrace.
  # 
  #  @return [Fixnum]
  #  @return [Infinity] (rails)
  #
  def bump_index!
    @bt_index += 1
  end

  def bt_source_location_for(index)
    backtrace[index] =~ /(.*):(\d+)/
    [$1, $2.to_i]
  end
end
