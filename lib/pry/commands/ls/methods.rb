require 'pry/commands/ls/jruby_hacks'
require 'pry/commands/ls/methods_helper'
require 'pry/commands/ls/interrogateable'

class Pry
  class Command::Ls < Pry::ClassCommand
    class Methods < Pry::Command::Ls::Formatter

      include Pry::Command::Ls::Interrogateable
      include Pry::Command::Ls::JRubyHacks
      include Pry::Command::Ls::MethodsHelper

      def initialize(interrogatee, has_any_opts, opts)
        @interrogatee = interrogatee
        @has_any_opts = has_any_opts
        @default_switch = opts[:methods]
        @instance_methods_switch = opts['instance-methods']
        @ppp_switch = opts[:ppp]
        @jruby_switch = opts['all-java']
        @quiet_switch = opts[:quiet]
      end

      def correct_opts?
        super || @instance_methods_switch || @ppp_switch || !@has_any_opts
      end

      def output_self
        methods = all_methods.group_by(&:owner)
        # Reverse the resolution order so that the most useful information
        # appears right by the prompt.
        resolution_order.take_while(&below_ceiling).reverse.map do |klass|
          methods_here = grep.regexp[format((methods[klass] || []))]
          heading = "#{ Pry::WrappedModule.new(klass).method_prefix }methods"
          output_section(heading, methods_here)
        end.join('')
      end

      # Format and colourise a list of methods.
      def format(methods)
        methods.sort_by(&:name).map do |method|
          if method.name == 'method_missing'
            color(:method_missing, 'method_missing')
          elsif method.visibility == :private
            color(:private_method, method.name)
          elsif method.visibility == :protected
            color(:protected_method, method.name)
          else
            color(:public_method, method.name)
          end
        end
      end

    end
  end
end
