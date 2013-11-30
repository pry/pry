module Pry::Command::Ls::MethodsHelper

  # Get all the methods that we'll want to output.
  def all_methods(instance_methods = false)
    methods = if instance_methods || @instance_methods_switch
                Pry::Method.all_from_class(@interrogatee)
              else
                Pry::Method.all_from_obj(@interrogatee)
              end

    if Pry::Helpers::BaseHelpers.jruby? && !@jruby_switch
      methods = trim_jruby_aliases(methods)
    end

    methods.select { |method| @ppp_switch || method.visibility == :public }
  end

  def resolution_order
    if @instance_methods_switch
      Pry::Method.instance_resolution_order(@interrogatee)
    else
      Pry::Method.resolution_order(@interrogatee)
    end
  end

  # Get a lambda that can be used with `take_while` to prevent over-eager
  # traversal of the Object's ancestry graph.
  def below_ceiling
    ceiling = if @quiet_switch
                [Pry::Method.safe_send(interrogatee_mod, :ancestors)[1]] +
                  Pry.config.ls.ceiling
              elsif @verbose_switch
                []
              else
                Pry.config.ls.ceiling.dup
              end
    lambda { |klass| !ceiling.include?(klass) }
  end

end
