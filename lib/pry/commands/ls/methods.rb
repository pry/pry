require 'pry/commands/ls/methods_helper'
require 'pry/commands/ls/interrogateable'

class Pry
  class Command::Ls < Pry::ClassCommand
    class Methods < Pry::Command::Ls::Formatter

      include Pry::Command::Ls::Interrogateable
      include Pry::Command::Ls::MethodsHelper

      def initialize(interrogatee, no_user_opts, opts)
        @interrogatee = interrogatee
        @no_user_opts = no_user_opts
        @default_switch = opts[:methods]
        @instance_methods_switch = opts['instance-methods']
        @ppp_switch = opts[:ppp]
        @jruby_switch = opts['all-java']
        @quiet_switch = opts[:quiet]
        @verbose_switch = opts[:verbose]
      end

      def output_self
        methods = all_methods.group_by(&:owner)
        # Reverse the resolution order so that the most useful information
        # appears right by the prompt.
        resolution_order.take_while(&below_ceiling).reverse.map do |klass|
          methods_here = (methods[klass] || []).select { |m| grep.regexp[m.name] }
          heading = "#{ Pry::WrappedModule.new(klass).method_prefix }methods"
          output_section(heading, format(methods_here))
        end.join('')
      end

      private

      def correct_opts?
        super || @instance_methods_switch || @ppp_switch || @no_user_opts
      end


      # Get a lambda that can be used with `take_while` to prevent over-eager
      # traversal of the Object's ancestry graph.
      def below_ceiling
        if @instance_methods_switch
          instance_ceiling
        else
          ceiling
        end
      end

      def instance_ceiling
        ceiling = if Pry.config.ls.ceiling.include?(@interrogatee) # when BasicObject, Object, Module, Class 
                    if @quiet_switch
                      Pry.config.ls.ceiling.dup - [@interrogatee] + [Pry::Method.safe_send(@interrogatee, :ancestors)[1]]
                    elsif @verbose_switch
                      []
                    else
                      Pry.config.ls.ceiling.dup - [@interrogatee]
                    end
                  else
                    if @quiet_switch
                      [Pry::Method.safe_send(interrogatee_mod, :ancestors)[1]] +
                        Pry.config.ls.ceiling
                    elsif @verbose_switch
                      []
                    else
                      Pry.config.ls.ceiling.dup                      
                    end
                  end
        lambda { |klass| !ceiling.include?(klass) }
      end

      def ceiling
        ceiling = if Pry.config.ls.ceiling.include?(@interrogatee) # when BasicObject, Object, Module, Class
                    if @verbose_switch
                      []
                    else
                      Pry.config.ls.ceiling.dup - [Pry::Method.singleton_class_of(@interrogatee)]
                    end
                  elsif Pry::Method.instance_of_basicobject?(@interrogatee) # when BasicObject.new
                    Pry.config.ls.ceiling.dup - [BasicObject]
                  elsif Pry.config.ls.ceiling.include?(@interrogatee.class) # when Object.new, Module.new, Class.new
                    if @quiet_switch
                      Pry.config.ls.ceiling.dup - [@interrogatee.class] + [Pry::Method.safe_send(@interrogatee.class, :ancestors)[1]]
                    elsif @verbose_switch
                      []
                    else
                      Pry.config.ls.ceiling.dup - [@interrogatee.class]
                    end
                  elsif @quiet_switch
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
  end
end
