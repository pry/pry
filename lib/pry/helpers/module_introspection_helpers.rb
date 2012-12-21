class Pry
  module Helpers
    module ModuleIntrospectionHelpers
      attr_accessor :module_object

      def module_object
        if @module_object
          @module_object
        else
          name = args.first
          @module_object = WrappedModule.from_str(name, target)
          if @module_object
            sup = @module_object.ancestors.select do |anc|
              anc.class == @module_object.wrapped.class
            end[opts[:super]]
            @module_object = sup ? Pry::WrappedModule(sup) : nil
          end
        end
      end

      # @param [String] input
      # @param [Binding] target The binding context of the input.
      # @return [Symbol] type of input
      def input_type(input, target)
        if input == ""
          :blank
        elsif target.eval("defined? #{input} ") =~ /variable|constant/ &&
              target.eval(input).respond_to?(:source_location)
          :sourcable_object
        elsif co = retrieve_code_object_from_string(input, target)
          co.is_a?(Pry::Method) ? :method : :module
        elsif target.eval("defined?(#{input})") =~ /variable|constant/
          :variable_or_constant
        elsif find_command(input)
          :command
        else
          :unknown
        end
      rescue SyntaxError
        if find_command(input)
          :command
        else
          :unknown
        end
      end

      def process(name)
        input = args.join(" ").gsub(/\"/,"")
        type = input_type(input, target)

        code_or_doc = case type
                      when :blank
                        process_blank
                      when :sourcable_object
                        process_sourcable_object
                      when :method
                        process_method
                      when :module
                        process_module
                      when :variable_or_constant
                        process_variable_or_constant
                      when :command
                        process_command
                      else
                        saught_in_vain = (input =~ /[.#]/ ? 'undefined method' :
                                          input =~ (/::|^[A-Z]/) ? 'uninitialized constant' :
                                          input =~ /^$/ ? 'uninitialized global' :
                                                   'undefined local variable or method')
                        command_error("#{saught_in_vain} `#{input}'", true)
                      end

        render_output(code_or_doc, opts)
      end

      def process_blank
        if mod = extract_module_from_internal_binding
          @module_object = mod
          process_module
        elsif meth = extract_method_from_binding
          @method_object = meth
          process_method
        else
          command_error("no current source", false)
        end
      end

      def extract_module_from_internal_binding
        if args.empty? && internal_binding?(target)
          mod = target_self.is_a?(Module) ? target_self : target_self.class
          Pry::WrappedModule(mod)
        end
      end

      def extract_method_from_binding
        Pry::Method.from_binding(target)
      end

      def process_variable_or_constant
        name = args.first
        object = target.eval(name)

        @module_object = Pry::WrappedModule(object.class)
        process_module
      end

      def module_start_line(mod, candidate_rank=0)
        if opts.present?(:'base-one')
          1
        else
          mod.candidate(candidate_rank).line
        end
      end

      def use_line_numbers?
        opts.present?(:b) || opts.present?(:l)
      end

      def attempt
        rank = 0
        begin
          yield(rank)
        rescue Pry::CommandError
          raise if rank > (module_object.number_of_candidates - 1)
          rank += 1
          retry
        end
      end

    end
  end
end
