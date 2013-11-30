class Pry
  class Command::Ls < Pry::ClassCommand
    class SelfMethods < Pry::Command::Ls::Formatter

      include Pry::Command::Ls::Interrogateable
      include Pry::Command::Ls::MethodsHelper

      def initialize(interrogatee, has_any_opts, opts)
        @interrogatee = interrogatee
        @has_any_opts = has_any_opts
      end

      def correct_opts?
        !@has_any_opts && interrogating_a_module?
      end

      def output_self
        methods = all_methods(true).select do |m|
          m.owner == @interrogatee && grep.regexp[m.name]
        end
        heading = "#{ Pry::WrappedModule.new(@interrogatee).method_prefix }methods"
        output_section(heading, format(methods))
      end

    end
  end
end
