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

      def find_command(name)
        command_match = commands.find { |_, command| command.options[:listing] == name }

        return command_match.last if command_match
        nil
      end

      def gem_installed?(gem_name)
        require 'rubygems'
        Gem::Specification.respond_to?(:find_all_by_name) ? !Gem::Specification.find_all_by_name(gem_name).empty? : Gem.source_index.find_name(gem_name).first
      end

      def not_a_real_file?(file)
        file =~ /(\(.*\))|<.*>/ || file =~ /__unknown__/ || file == "" || file == "-e"
      end

      def command_dependencies_met?(options)
        return true if !options[:requires_gem]
        Array(options[:requires_gem]).all? do |g|
          gem_installed?(g)
        end
      end

      def set_file_and_dir_locals(file_name)
        return if !target or !file_name
        _pry_.last_file = File.expand_path(file_name)
        _pry_.inject_local("_file_", _pry_.last_file, target)

        _pry_.last_dir = File.dirname(_pry_.last_file)
        _pry_.inject_local("_dir_", _pry_.last_dir, target)
      end

      def stub_proc(name, options)
        gems_needed = Array(options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }
        proc do
          output.puts "\nThe command '#{name}' requires the following gems to be installed: #{(gems_needed.join(", "))}"
          output.puts "-"
          output.puts "Command not available due to dependency on gems: `#{gems_not_installed.join(", ")}` not being met."
          output.puts "-"
          output.puts "Type `install #{name}` to install the required gems and activate this command."
        end
      end

      def create_command_stub(names, description, options, block)
        Array(names).each do |name|
          commands[name] = {
            :description => "Not available. Execute #{(name)} command for more information.",
            :action => stub_proc(name, options),
            :stub_info => options
          }
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

      # are we on Jruby platform?
      def jruby?
        RbConfig::CONFIG['ruby_install_name'] == 'jruby'
      end

      # are we on rbx platform?
      def rbx?
        RbConfig::CONFIG['ruby_install_name'] == 'rbx'
      end

      def mri_18?
        RUBY_VERSION =~ /1.8/ && RbConfig::CONFIG['ruby_install_name'] == 'ruby'
      end

      def mri_19?
        RUBY_VERSION =~ /1.9/ && RbConfig::CONFIG['ruby_install_name'] == 'ruby'
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

        if text.lines.count < Pry::Pager.page_size || !Pry.pager
          out.puts text
        else
          Pry::Pager.page(text)
        end
      rescue Errno::ENOENT
        Pry::Pager.page(text, :simple)
      rescue Errno::EPIPE
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

            output.puts "Bad object path: #{arg_string.chomp}. Failed trying to resolve: #{context}"
            output.puts e.inspect
            return nil, state_old_stack
          end
        end
        return stack, state_old_stack
      end

    end
  end
end
