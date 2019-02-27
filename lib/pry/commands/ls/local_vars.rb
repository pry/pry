class Pry
  class Command
    class Ls < Pry::ClassCommand
      class LocalVars < Pry::Command::Ls::Formatter
        def initialize(opts, _pry_)
          super(_pry_)
          @default_switch = opts[:locals]
          @sticky_locals = _pry_.sticky_locals
        end

        def output_self
          name_value_pairs = @target.eval('local_variables').reject do |e|
            @sticky_locals.key?(e.to_sym)
          end.map do |name|
            [name, (@target.eval(name.to_s))]
          end
          format(name_value_pairs).join('')
        end

        private

        def format(name_value_pairs)
          name_value_pairs.sort_by do |_name, value|
            value.to_s.size
          end.reverse.map do |name, value|
            colorized_assignment_style(name, format_value(value))
          end
        end

        def colorized_assignment_style(lhs, rhs, desired_width = 7)
          colorized_lhs = color(:local_var, lhs)
          color_escape_padding = colorized_lhs.size - lhs.size
          pad = desired_width + color_escape_padding
          "%-#{pad}s = %s" % [color(:local_var, colorized_lhs), rhs]
        end
      end
    end
  end
end
