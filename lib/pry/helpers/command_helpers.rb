class Pry
  module Helpers

    module CommandHelpers
      include OptionsHelpers

      module_function

      # Open a temp file and yield it to the block, closing it after
      # @return [String] The path of the temp file
      def temp_file(ext='.rb')
        file = Tempfile.new(['pry', ext])
        yield file
      ensure
        file.close(true) if file
      end

      def render_output(str, opts={})
        if opts[:flood]
          output.puts str
        else
          stagger_output str
        end
      end

      # Given a string and a binding, return the corresponding
      # `Pry::Method` or `Pry::WrappedModule`. Also give precedence to modules
      # when the `::` syntax is used.
      # @param [String] input The full name of the method or module.
      # @param [Binding] target The binding where the object is found.
      # @return [Pry::WrappedModule, Pry::Method] The relevant code object.
      def retrieve_code_object_from_string(input, target)

        # ensure modules have precedence when `MyClass::X` syntax is used.
        if input =~ /::(?:\S+)\Z/
          Pry::WrappedModule.from_str(input,target) || Pry::Method.from_str(input, target)
        else
          Pry::Method.from_str(input,target) || Pry::WrappedModule.from_str(input, target)
        end
      end

      # Return the file and line for a Binding.
      # @param [Binding] target The binding
      # @return [Array] The file and line
      def file_and_line_from_binding(target)
        file = target.eval('__FILE__')
        line_num = target.eval('__LINE__')
        if rbx?
          if !target.instance_variable_defined?(:@__actual_file__)
            target.instance_variable_set(:@__actual_file__, RbxPath.convert_path_to_full(target.variables.method.file.to_s))
          end
          file = target.instance_variable_get(:@__actual_file__).to_s
        end

        [file, line_num]
      end

      def internal_binding?(target)
        m = target.eval("::Kernel.__method__").to_s
        # class_eval is here because of http://jira.codehaus.org/browse/JRUBY-6753
        ["__binding__", "__pry__", "class_eval"].include?(m)
      end

      def get_method_or_raise(name, target, opts={}, omit_help=false)
        meth = Pry::Method.from_str(name, target, opts)

        if name && !meth
          command_error("The method '#{name}' could not be found.", omit_help, MethodNotFound)
        end

        (opts[:super] || 0).times do
          if meth.super
            meth = meth.super
          else
            command_error("'#{meth.name_with_owner}' has no super method.", omit_help, MethodNotFound)
          end
        end

        if !meth || (!name && internal_binding?(target))
          command_error("No method name given, and context is not a method.", omit_help, MethodNotFound)
        end

        set_file_and_dir_locals(meth.source_file)
        meth
      end

      def command_error(message, omit_help, klass=CommandError)
        message += " Type `#{command_name} --help` for help." unless omit_help
        raise klass, message
      end

      def make_header(meth, content=meth.source)
        header = "\n#{Pry::Helpers::Text.bold('From:')} #{meth.source_file} "

        if meth.source_type == :c
          header << "(C Method):\n"
        else
          header << "@ line #{meth.source_line}:\n"
        end

        header << "#{Pry::Helpers::Text.bold("Number of lines:")} #{content.each_line.count.to_s}\n"
      end

      # Remove any common leading whitespace from every line in `text`.
      #
      # This can be used to make a HEREDOC line up with the left margin, without
      # sacrificing the indentation level of the source code.
      #
      # e.g.
      #   opt.banner unindent <<-USAGE
      #     Lorem ipsum dolor sit amet, consectetur adipisicing elit,
      #     sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
      #       "Ut enim ad minim veniam."
      #   USAGE
      #
      # Heavily based on textwrap.dedent from Python, which is:
      #   Copyright (C) 1999-2001 Gregory P. Ward.
      #   Copyright (C) 2002, 2003 Python Software Foundation.
      #   Written by Greg Ward <gward@python.net>
      #
      #   Licensed under <http://docs.python.org/license.html>
      #   From <http://hg.python.org/cpython/file/6b9f0a6efaeb/Lib/textwrap.py>
      #
      # @param [String] text The text from which to remove indentation
      # @return [String] The text with indentation stripped.
      def unindent(text, left_padding = 0)
        # Empty blank lines
        text = text.sub(/^[ \t]+$/, '')

        # Find the longest common whitespace to all indented lines
        margin = text.scan(/^[ \t]*(?=[^ \t\n])/).inject do |current_margin, next_indent|
          if next_indent.start_with?(current_margin)
            current_margin
          elsif current_margin.start_with?(next_indent)
            next_indent
          else
            ""
          end
        end

        text.gsub(/^#{margin}/, ' ' * left_padding)
      end

      # Restrict a string to the given range of lines (1-indexed)
      # @param [String] content The string.
      # @param [Range, Fixnum] lines The line(s) to restrict it to.
      # @return [String] The resulting string.
      def restrict_to_lines(content, lines)
        line_range = one_index_range_or_number(lines)
        Array(content.lines.to_a[line_range]).join
      end

      def one_index_number(line_number)
        if line_number > 0
          line_number - 1
        else
          line_number
        end
      end

      # convert a 1-index range to a 0-indexed one
      def one_index_range(range)
        Range.new(one_index_number(range.begin), one_index_number(range.end))
      end

      def one_index_range_or_number(range_or_number)
        case range_or_number
        when Range
          one_index_range(range_or_number)
        else
          one_index_number(range_or_number)
        end
      end

      def absolute_index_number(line_number, array_length)
        if line_number >= 0
          line_number
        else
          [array_length + line_number, 0].max
        end
      end

      def absolute_index_range(range_or_number, array_length)
        case range_or_number
        when Range
          a = absolute_index_number(range_or_number.begin, array_length)
          b = absolute_index_number(range_or_number.end, array_length)
        else
          a = b = absolute_index_number(range_or_number, array_length)
        end

        Range.new(a, b)
      end

      # Get the gem spec object for the given gem
      # @param [String] gem name
      # @return [Gem::Specification]
      def gem_spec(gem)
        specs = if Gem::Specification.respond_to?(:each)
                  Gem::Specification.find_all_by_name(gem)
                else
                  Gem.source_index.find_name(gem)
                end

        spec = specs.sort_by{ |spec| Gem::Version.new(spec.version) }.first

        spec or raise CommandError, "Gem `#{gem}` not found"
      end

      # List gems matching a pattern
      # @param [Regexp] pattern
      # @return [Array<Gem::Specification>]
      def gem_list(pattern=/.*/)
        if Gem::Specification.respond_to?(:each)
          Gem::Specification.select{|spec| spec.name =~ pattern }
        else
          Gem.source_index.gems.values.select{|spec| spec.name =~ pattern }
        end
      end

      # Completion function for gem-cd and gem-open
      # @param [String] so_far what the user's typed so far
      # @return [Array<String>] completions
      def gem_complete(so_far)
        if so_far =~ / ([^ ]*)\z/
          gem_list(%r{\A#{$2}}).map(&:name)
        else
          gem_list.map(&:name)
        end
      end
    end
  end
end
