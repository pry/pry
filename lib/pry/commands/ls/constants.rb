class Pry
  class Command::Ls < Pry::ClassCommand
    class Constants < Pry::Command::Ls::Formatter

      def initialize(interrogatee, target, has_any_opts, opts)
        super(target)
        @interrogatee = interrogatee
        @has_any_opts = has_any_opts
        @default_switch = opts[:constants]
        @verbose_switch = opts[:verbose]
      end

      def correct_opts?
        super || (!@has_any_opts && Module === @interrogatee)
      end

      def interrogatee_mod
        if Module === @interrogatee
          @interrogatee
        else
          class << @interrogatee
            ancestors.grep(::Class).reject { |c| c == self }.first
          end
        end
      end

      def output_self
        mod = interrogatee_mod
        constants = WrappedModule.new(mod).constants(@verbose_switch)
        output_section('constants', grep.regexp[format(mod, constants)])
      end

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
