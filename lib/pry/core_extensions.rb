class Object
  # Start a Pry REPL.
  # This method differs from `Pry.start` in that it does not
  # support an options hash. Also, when no parameter is provided, the Pry
  # session will start on the implied receiver rather than on
  # top-level (as in the case of `Pry.start`).
  # It has two forms of invocation. In the first form no parameter
  # should be provided and it will start a pry session on the
  # receiver. In the second form it should be invoked without an
  # explicit receiver and one parameter; this will start a Pry
  # session on the parameter.
  # @param [Object, Binding] target The receiver of the Pry session.
  # @example First form
  #   "dummy".pry
  # @example Second form
  #    pry "dummy"
  # @example Start a Pry session on current self (whatever that is)
  #   pry
  def pry(target=self)
    Pry.start(target)
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
