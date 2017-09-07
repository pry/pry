def Pry.Rescuable(pry = nil)
  Module.new do
    define_singleton_method(:===) do |e|
      case e
      when Interrupt then true
      when *(pry or Pry).config.exception_whitelist then false
      else true
      end
    end
  end
end
