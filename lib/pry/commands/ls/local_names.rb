class Pry
  class Command::Ls < Pry::ClassCommand
    class LocalNames < Pry::Command::Ls::Formatter

      def initialize(target, has_any_opts, sticky_locals, args)
        super(target)
        @has_any_opts = has_any_opts
        @sticky_locals = sticky_locals
        @args = args
      end

      def correct_opts?
        super || !@has_any_opts && @args.empty?
      end

      def output_self
        local_vars = grep.regexp[@target.eval('local_variables')]
        output_section('locals', format(local_vars))
      end

      def format(locals)
        locals.sort_by(&:downcase).map do |name|
          if @sticky_locals.include?(name.to_sym)
            color(:pry_var, name)
          else
            color(:local_var, name)
          end
        end
      end

    end
  end
end
