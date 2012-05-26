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
  def __binding__
    if is_a?(Module)
      return class_eval "binding"
    end

    unless respond_to? :__binding_impl__
      begin
        instance_eval %{
          def __binding_impl__
            binding
          end
        }
      rescue TypeError
        self.class.class_eval %{
          def __binding_impl__
            binding
          end
        }
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
