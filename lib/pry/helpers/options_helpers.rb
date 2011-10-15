class Pry
  module Helpers
    module OptionsHelpers
      module_function

      # Use Slop to parse the arguments given.
      #
      # @param [Array] mutable list of arguments
      # @param [Hash] predefined option types
      # @param [&Block] used to add custom arguments.
      #
      # @return Slop::Options
      #
      # @option [Boolean] :method_object
      #   Set to true if you want to get a method object from the user.
      #
      def parse_options!(args, predefined={}, &block)
        Slop.parse!(args) do |opt|
          add_method_object_options(opt) if predefined[:method_object]

          yield opt
          opt.on :h, :help, "This message" do
            output.puts opt
            throw :command_done
          end

        end.tap do |opts|
          process_method_object_options(args, opts) if predefined[:method_object]
        end
      end

      # Add the method object options to an unused Slop instance.
      def add_method_object_options(opt)
        @method_target = target
        opt.on :M, "instance-methods", "Operate on instance methods."
        opt.on :m, :methods, "Operate on methods."
        opt.on :c, :context, "Select object context to run under.", true do |context|
          @method_target = Pry.binding_for(target.eval(context))
        end
      end

      # Add the derived :method_object option to a used Slop instance.
      def process_method_object_options(args, opts)
        opts[:instance] = opts['instance-methods'] if opts.m?
        method_obj = get_method_or_raise(args.empty? ? nil : args.join(" "), @method_target, opts.to_hash(true))
        opts.on(:method_object, :default => method_obj)
      end
    end
  end
end
