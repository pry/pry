class Pry::BasicObject < BasicObject
  ::Object.constants.each do |constant|
    const_set constant, ::Object.const_get(constant)
  end
  include Kernel
end
