class Pry::BasicObject < BasicObject
  Pry = ::Pry
  Kernel = ::Kernel
  include Kernel
end
