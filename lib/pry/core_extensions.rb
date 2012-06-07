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
  # We need to care about at least three things when creating a binding:
  #
  # 1. What's 'self'? (hopefully the object you called .pry on)
  # 2. What locals are available? (hopefully none!)
  # 3. Where do methods get defined when you use 'def'?
  #
  # Setting the "default definee" correctly is why this code is so complicated,
  # for a detailed explanation of that concept, see http://yugui.jp/articles/846
  #
  # @return Binding
  def __binding__
    # When you're cd'd into a class, methods you define should be added to that
    # class. It's just like `class Foo; binding.pry; end`
    if is_a?(Module)
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
        # @return Binding
        def __binding_impl__
          binding
        end
      METHOD

      # When you're in an object that supports defining methods on its
      # singleton class (i.e. a normal object), then we want to define methods
      # on the singleton class itself. This works in the same way as if you'd
      # done: `self.instance_eval{ binding.pry }`
      #
      # The easiest way to check whether this approach will work is to try and
      # define a method on the singleton_class. (just checking for the presence
      # of the singleton class gives false positives for `true` and `false`).
      # __binding_impl__ is just the closest method we have to hand, and using
      # it has the nice property that we can memoize this check.
      #
      begin
        instance_eval binding_impl_method

      # If we can't define methods on the Object's singleton_class (either
      # because it hasn't got one, e.g. Fixnum, Symbol, or its not a proper
      # singleton class, e.g. TrueClass, FalseClass). Then we fall back to
      # setting the default definee to be the Object's class. That seems nicer
      # than having a REPL in which you can't define methods.
      rescue TypeError
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
