class Pry::BasicObject < BasicObject
  Pry = ::Pry
  Kernel = ::Kernel
  include Kernel
  alias_method :object_id, :__id__
  alias_method :eql?, :==
end
