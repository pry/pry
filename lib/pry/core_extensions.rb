class Object
  # Start a Pry REPL on self.
  #
  # If `self` is a Binding then that will be used to evaluate expressions;
  # otherwise a new binding will be created.
  #
  # @param [Object] object  the object or binding to pry
  #                         (__deprecated__, use `object.pry`)
  # @param [Hash] hash  the options hash
  # @example With a binding
  #    binding.pry
  # @example On any object
  #   "dummy".pry
  # @example With options
  #   def my_method
  #     binding.pry :quiet => true
  #   end
  #   my_method()
  # @see Pry.start
  def pry(object=nil, hash={})
    if object.nil? || Hash === object
      Pry.start(self, object || {})
    else
      Pry.start(object, hash)
    end
  end

  # Return a binding object for the receiver.
  #
  # The `self` of the binding is set to the current object, and it contains no
  # local variables.
  #
  # The default definee (http://yugui.jp/articles/846) is set such that:
  #
  # * If `self` is a class or module, then new methods created in the binding
  #   will be defined in that class or module (as in `class Foo; end`).
  # * If `self` is a normal object, then new methods created in the binding will
  #   be defined on its singleton class (as in `class << self; end`).
  # * If `self` doesn't have a  real singleton class (i.e. it is a Fixnum, Float,
  #   Symbol, nil, true, or false), then new methods will be created on the
  #   object's class (as in `self.class.class_eval{ }`)
  #
  # Newly created constants, including classes and modules, will also be added
  # to the default definee.
  #
  # @return [Binding]
  def __binding__
    # When you're cd'd into a class, methods you define should be added to it.
    if is_a?(Module)
      # class_eval sets both self and the default definee to this class.
      return class_eval "binding"
    end

    unless respond_to?(:__pry__)
      binding_impl_method = [<<-METHOD, __FILE__, __LINE__ + 1]
        # Get a binding with 'self' set to self, and no locals.
        #
        # The default definee is determined by the context in which the
        # definition is eval'd.
        #
        # Please don't call this method directly, see {__binding__}.
        #
        # @return [Binding]
        def __pry__
          binding
        end
      METHOD

      # The easiest way to check whether an object has a working singleton class
      # is to try and define a method on it. (just checking for the presence of
      # the singleton class gives false positives for `true` and `false`).
      # __pry__ is just the closest method we have to hand, and using
      # it has the nice property that we can memoize this check.
      begin
        # instance_eval sets the default definee to the object's singleton class
        instance_eval(*binding_impl_method)

      # If we can't define methods on the Object's singleton_class. Then we fall
      # back to setting the default definee to be the Object's class. That seems
      # nicer than having a REPL in which you can't define methods.
      rescue TypeError
        # class_eval sets the default definee to self.class
        self.class.class_eval(*binding_impl_method)
      end
    end

    __pry__
  end
end

# There's a splat bug on jruby in 1.9 emulation mode, which breaks the
# pp library.
#
# * http://jira.codehaus.org/browse/JRUBY-6687
# * https://github.com/pry/pry/issues/568
#
# Until that gets fixed upstream, let's monkey-patch here:
if [[1, 2]].pretty_inspect == "[1]\n"
  class Array
    def pretty_print(q)
      q.group(1, '[', ']') {
        i = 0
        q.seplist(self) { |*|
          q.pp self[i]
          i += 1
        }
      }
    end
  end
end
