module Pry::Config::Lazy
  LAZY_KEYS = {}
  LAZY_KEYS.default_proc = lambda {|h,k| h[k] = [] }

  module ExtendModule
    def lazy_implement(method_name_to_func)
      method_name_to_func.each do |method_name, func|
        define_method(method_name) do
          if method_name_to_func[method_name].equal?(func)
            LAZY_KEYS[self.class] |= method_name_to_func.keys
            method_name_to_func[method_name] = instance_eval(&func)
          end
          method_name_to_func[method_name]
        end
      end
    end
  end

  def self.included(includer)
    includer.extend(ExtendModule)
  end

  def lazy_keys
    LAZY_KEYS[self.class]
  end
end
