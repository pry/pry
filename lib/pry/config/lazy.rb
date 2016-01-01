module Pry::Config::Lazy
  LAZY_KEYS = Hash.new {|h,k| h[k] = [] }

  module ClassMethods
    def lazy_implement(method_name_to_func)
      method_name_to_func.each do |method_name, func|
        define_method(method_name) do
          if method_name_to_func[method_name].equal?(func)
            method_name_to_func[method_name] = instance_eval(&func)
          end
          method_name_to_func[method_name]
        end
      end
      LAZY_KEYS[self] |= method_name_to_func.keys
    end
  end

  def self.included(includer)
    includer.extend(ClassMethods)
  end

  def lazy_keys
    LAZY_KEYS[self.class]
  end
end
