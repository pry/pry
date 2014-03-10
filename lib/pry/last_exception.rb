class Pry::LastException < BasicObject
  attr_reader :file, :line
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

  def respond_to_missing?(name, boolean=false)
    @e.respond_to?(name)
  end

  def pry?
    true
  end

  def bt_source_location_for(index)
    backtrace[index] =~ /(.*):(\d+)/
    [$1, $2.to_i]
  end

  def inc_bt_index
    @bt_index = (@bt_index + 1) % backtrace.size
  end
end
