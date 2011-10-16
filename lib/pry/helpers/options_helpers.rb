class Pry
  module Helpers
    module OptionsHelpers
      module_function

      # Use Slop to parse the arguments given.
      #
      # @param [Array] args  The options are stripped out by Slop.
      # @param [*Symbol] extras  Extra features you want returned.
      # @param [&Block]  used to add custom arguments to Slop.
      #
      # @option [Extra] :method_object Returns a method object.
      #
      # @return Slop::Options iff you don't pass any extras.
      # @return [Array]  If you do pass extras, an array is returned where the first argument is the
      # Slop::Options object, and the remainder are the extras you requested in order.
      #
      def parse_options!(args, *extras, &block)
        opts = Slop.parse!(args) do |opt|
          extras.each{ |extra| send(:"add_#{extra}_options", opt) }

          yield opt

          opt.on :h, :help, "This message" do
            output.puts opt
            throw :command_done
          end
        end

        if extras.empty?
          opts
        else
          [opts] + extras.map{ |extra| send(:"process_#{extra}_options", args, opts) }
        end
      end

      # Add the method object options to an unused Slop instance.
      def add_method_object_options(opt)
        @method_target = target
        opt.on :M, "instance-methods", "Operate on instance methods."
        opt.on :m, :methods, "Operate on methods."
        opt.on :s, :super, "Select the 'super' method. Can be repeated to traverse the ancestors."
        opt.on :c, :context, "Select object context to run under.", true do |context|
          @method_target = Pry.binding_for(target.eval(context))
        end
      end

      # Add the derived :method_object option to a used Slop instance.
      def process_method_object_options(args, opts)
        opts[:instance] = opts['instance-methods'] if opts.m?
        # TODO: de-hack when we upgrade Slop: https://github.com/injekt/slop/pull/30
        opts.options[:super].force_argument_value opts.options[:super].count if opts.super?

        get_method_or_raise(args.empty? ? nil : args.join(" "), @method_target, opts.to_hash(true))
      end
    end
  end
end
