class Pry
  module ObjectExtensions
    def pry(target=self, options={})
      Pry.start(target, options)
    end

    def __binding__
      if is_a?(Module)
        return class_eval "binding"
      end

      unless respond_to? :__binding_impl__
        self.class.class_eval <<-EXTRA
        def __binding_impl__
          binding
        end
        EXTRA
      end

      __binding_impl__
    end
  end
end

# bring the extensions into Object
class Object
  include Pry::ObjectExtensions
end
