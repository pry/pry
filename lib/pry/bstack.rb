class Pry::BStack < BasicObject 
  def initialize(pry)
    @b = []
  end

  def method_missing(m, *argz, &blk)
    @b.public_send(m, *argz, &blk)
  end
end