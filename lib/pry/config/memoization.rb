module Pry::Config::Memoization
  MEMOIZED_METHODS = Hash.new {|h,k| h[k] = [] }

  module ClassMethods
    def def_memoized(method_table)
      method_table.each do |method_name, method|
        define_method(method_name) do
          method_table[method_name] = instance_eval(&method) if method_table[method_name].equal? method
          method_table[method_name]
        end
      end
      MEMOIZED_METHODS[self] |= method_table.keys
    end
  end

  def self.included(mod)
    mod.extend(ClassMethods)
  end

  def memoized_methods
    MEMOIZED_METHODS[self.class]
  end
end
