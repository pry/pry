require 'pry/commands/ls/interrogatable'

class Pry
  class Command::Ls < Pry::ClassCommand
    class Constants < Pry::Command::Ls::Formatter
      include Pry::Command::Ls::Interrogatable


      def initialize(interrogatee, no_user_opts, opts, _pry_)
        super(_pry_)
        @interrogatee = interrogatee
        @no_user_opts = no_user_opts
        @default_switch = opts[:constants]
        @verbose_switch = opts[:verbose]
      end

      def correct_opts?
        super || (@no_user_opts && interrogating_a_module?)
      end

      def output_self
        mod = interrogatee_mod
        constants = WrappedModule.new(mod).constants(@verbose_switch)
        output_section('constants', grep.regexp[format(mod, constants)])
      end

      private

      def format(mod, constants)
        constants.sort_by(&:downcase).map do |name|
          if const = (!mod.autoload?(name) && (mod.const_get(name) || true) rescue nil)
            if (const < Exception rescue false)
              color(:exception_constant, name)
            elsif (Module === mod.const_get(name) rescue false)
              color(:class_constant, name)
            else
              color(:constant, name)
            end
          else
            color(:unloaded_constant, name)
          end
        end
      end

    end
  end
end
