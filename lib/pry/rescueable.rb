#
# Pry.Rescueable() is a method that returns an object for use with
# the 'rescue' keyword. The object decides if an exception should be
# rescued, or raised. See {Pry.config.exception_whitelist} for a default
# list of exceptions not rescued via this method.
#
# @param [Pry] pry
#   An instance of `Pry`, where `config.exception_whitelist` is read from.
#
# @return [Module]
#
# @example
#
#   # In some Pry command...
#   begin
#     _pry_.pager.page(str)
#   rescue Pry.Rescuable(_pry_) => e
#     puts [e.class, e.message]
#   end
#
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
