class Pry
  module Helpers

    module BaseHelpers

      module_function

      def silence_warnings
        old_verbose = $VERBOSE
        $VERBOSE = nil
        begin
          yield
        ensure
          $VERBOSE = old_verbose
        end
      end

      # Acts like send but ignores any methods defined below Object or Class in the
      # inheritance hierarchy.
      # This is required to introspect methods on objects like Net::HTTP::Get that
      # have overridden the `method` method.
      def safe_send(obj, method, *args, &block)
        (Module === obj ? Module : Object).instance_method(method).bind(obj).call(*args, &block)
      end
      public :safe_send

      def find_command(name, set = Pry::Commands)
        command_match = set.find do |_, command|
          (listing = command.options[:listing]) == name && listing != nil
        end
        command_match.last if command_match
      end

      def not_a_real_file?(file)
        file =~ /(\(.*\))|<.*>/ || file =~ /__unknown__/ || file == "" || file == "-e"
      end

      def command_dependencies_met?(options)
        return true if !options[:requires_gem]
        Array(options[:requires_gem]).all? do |g|
          Rubygem.installed?(g)
        end
      end

      def use_ansi_codes?
        windows_ansi? || ENV['TERM'] && ENV['TERM'] != "dumb"
      end

      def colorize_code(code)
        if Pry.color
          CodeRay.scan(code, :ruby).term
        else
          code
        end
      end

      def highlight(string, regexp, highlight_color=:bright_yellow)
        string.gsub(regexp) { |match| "<#{highlight_color}>#{match}</#{highlight_color}>" }
      end

      # formatting
      def heading(text)
        text = "#{text}\n--"
        Pry.color ? "\e[1m#{text}\e[0m": text
      end

      # have fun on the Windows platform.
      def windows?
        RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
      end

      # are we able to use ansi on windows?
      def windows_ansi?
        defined?(Win32::Console) || ENV['ANSICON']
      end

      def jruby?
        RbConfig::CONFIG['ruby_install_name'] == 'jruby'
      end

      def jruby_19?
        jruby? && RbConfig::CONFIG['ruby_version'] == '1.9'
      end

      def rbx?
        RbConfig::CONFIG['ruby_install_name'] == 'rbx'
      end

      def mri?
        RbConfig::CONFIG['ruby_install_name'] == 'ruby'
      end

      def mri_18?
        mri? && RUBY_VERSION =~ /1.8/
      end

      def mri_19?
        mri? && RUBY_VERSION =~ /1.9/
      end


      # Try to use `less` for paging, if it fails then use
      # simple_pager. Also do not page if Pry.pager is falsey
      def stagger_output(text, out = nil)
        out ||= case
                when respond_to?(:output)
                  # Mixin.
                  output
                when Pry.respond_to?(:output)
                  # Parent.
                  Pry.output
                else
                  # Sys.
                  $stdout
                end

        if Pry.pager
          Pry::Pager.page(text)
        else
          out.puts text
        end
      rescue Errno::ENOENT
        Pry::Pager.page(text, :simple)
      end

      # @param [String] arg_string The object path expressed as a string.
      # @param [Pry] _pry_ The relevant Pry instance.
      # @param [Array<Binding>] old_stack The state of the old binding stack
      # @return [Array<Array<Binding>, Array<Binding>>] An array
      #   containing two elements: The new `binding_stack` and the old `binding_stack`.
      def context_from_object_path(arg_string, _pry_=nil, old_stack=[])

        # Extract command arguments. Delete blank arguments like " ", but
        # don't delete empty strings like "".
        path      = arg_string.split(/\//).delete_if { |a| a =~ /\A\s+\z/ }
        stack     = _pry_.binding_stack.dup
        state_old_stack = old_stack

        # Special case when we only get a single "/", return to root.
        if path.empty?
          state_old_stack = stack.dup unless old_stack.empty?
          stack = [stack.first]
        end

        path.each_with_index do |context, i|
          begin
            case context.chomp
            when ""
              state_old_stack = stack.dup
              stack = [stack.first]
            when "::"
              state_old_stack = stack.dup
              stack.push(TOPLEVEL_BINDING)
            when "."
              next
            when ".."
              unless stack.size == 1
                # Don't rewrite old_stack if we're in complex expression
                # (e.g.: `cd 1/2/3/../4).
                state_old_stack = stack.dup if path.first == ".."
                stack.pop
              end
            when "-"
              unless old_stack.empty?
                # Interchange current stack and old stack with each other.
                stack, state_old_stack = state_old_stack, stack
              end
            else
              state_old_stack = stack.dup if i == 0
              stack.push(Pry.binding_for(stack.last.eval(context)))
            end

          rescue RescuableException => e
            # Restore old stack to its initial values.
            state_old_stack = old_stack

            msg = [
              "Bad object path: #{arg_string}.",
              "Failed trying to resolve: #{context}.",
              e.inspect
            ].join(' ')

            CommandError.new(msg).tap do |err|
              err.set_backtrace e.backtrace
              raise err
            end
          end
        end
        return stack, state_old_stack
      end

    end
  end
end
