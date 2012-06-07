class Object
  # Start a Pry REPL.  This method only differs from Pry.start in that it
  # assumes that the target is `self`.  It also accepts and passses the same
  # exact options hash that Pry.start accepts. POSSIBLE DEPRICATION WARNING:
  # In the future the backwards compatibility with pry(binding) could be
  # removed so please properly use Object.pry or if you use pry(binding)
  # switch Pry.start(binding).

  # @param [Binding] the binding or options hash if no binding needed.
  # @param [Hash] the options hash.
  # @example First
  #   "dummy".pry
  # @example Second
  #    binding.pry
  # @example An example with options
  #   def my_method
  #     binding.pry :quiet => true
  #   end
  #   my_method()

  def pry(*args)
    if args.first.is_a?(Hash) || args.length == 0
      args.unshift(self)
    end

    Pry.start(*args)
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

    unless respond_to?(:__binding_impl__)
      binding_impl_method = <<-METHOD
        # Get a binding with 'self' set to self, and no locals.
        #
        # The default definee is determined by the context in which the
        # definition is eval'd.
        #
        # Please don't call this method directly, see {__binding__}.
        #
        # @return [Binding]
        def __binding_impl__
          binding
        end
      METHOD

      # The easiest way to check whether an object has a working singleton class
      # is to try and define a method on it. (just checking for the presence of
      # the singleton class gives false positives for `true` and `false`).
      # __binding_impl__ is just the closest method we have to hand, and using
      # it has the nice property that we can memoize this check.
      begin
        # instance_eval sets the default definee to the object's singleton class
        instance_eval binding_impl_method

      # If we can't define methods on the Object's singleton_class. Then we fall
      # back to setting the default definee to be the Object's class. That seems
      # nicer than having a REPL in which you can't define methods.
      rescue TypeError
        # class_eval sets the default definee to self.class
        self.class.class_eval binding_impl_method
      end
    end

    __binding_impl__
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
