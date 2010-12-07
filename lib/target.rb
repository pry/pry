require './pry'

o = Object.new
class << o
  def pig;
    puts "pig!!!"
  end

  def horse?
    puts "HORSEY LOL"
  end
end

5.times {
  pry(o)
}
