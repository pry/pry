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
        m = target.eval("__method__").to_s
        # class_eval is here because of http://jira.codehaus.org/browse/JRUBY-6753
        ["__binding__", "__pry__", "class_eval"].include?(m)
      end

      def get_method_or_raise(name, target, opts={}, omit_help=false)
        meth = Pry::Method.from_str(name, target, opts)

        if name && !meth
          command_error("The method '#{name}' could not be found.", omit_help)
        end

        (opts[:super] || 0).times do
          if meth.super
            meth = meth.super
          else
            command_error("'#{meth.name_with_owner}' has no super method.", omit_help)
          end
        end

        if !meth || (!name && internal_binding?(target))
          command_error("No method name given, and context is not a method.", omit_help, NonMethodContextError)
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

      def invoke_editor(file, line, reloading)
        raise CommandError, "Please set Pry.config.editor or export $VISUAL or $EDITOR" unless Pry.config.editor
        if Pry.config.editor.respond_to?(:call)
          args = [file, line, reloading][0...(Pry.config.editor.arity)]
          editor_invocation = Pry.config.editor.call(*args)
        else
          editor_invocation = "#{Pry.config.editor} #{blocking_flag_for_editor(reloading)} #{start_line_syntax_for_editor(file, line)}"
        end
        return nil unless editor_invocation

        if jruby?
          begin
            require 'spoon'
            pid = Spoon.spawnp(*editor_invocation.split)
            Process.waitpid(pid)
          rescue FFI::NotFoundError
            system(editor_invocation)
          end
        else
          # Note we dont want to use Pry.config.system here as that
          # may be invoked non-interactively (i.e via Open4), whereas we want to
          # ensure the editor is always interactive
          system(editor_invocation) or raise CommandError, "`#{editor_invocation}` gave exit status: #{$?.exitstatus}"
        end
      end

      # Some editors that run outside the terminal allow you to control whether or
      # not to block the process from which they were launched (in this case, Pry).
      # For those editors, return the flag that produces the desired behavior.
      def blocking_flag_for_editor(block)
        case editor_name
        when /^emacsclient/
          '--no-wait' unless block
        when /^[gm]vim/
          '--nofork' if block
        when /^jedit/
          '-wait' if block
        when /^mate/, /^subl/
          '-w' if block
        end
      end

      # Return the syntax for a given editor for starting the editor
      # and moving to a particular line within that file
      def start_line_syntax_for_editor(file_name, line_number)
        if windows?
          file_name = file_name.gsub(/\//, '\\')
        end

        # special case for 1st line
        return file_name if line_number <= 1

        case editor_name
        when /^[gm]?vi/, /^emacs/, /^nano/, /^pico/, /^gedit/, /^kate/
          "+#{line_number} #{file_name}"
        when /^mate/, /^geany/
          "-l #{line_number} #{file_name}"
        when /^subl/
          "#{file_name}:#{line_number}"
        when /^uedit32/
          "#{file_name}/#{line_number}"
        when /^jedit/
          "#{file_name} +line:#{line_number}"
        else
          if windows?
            "#{file_name}"
          else
            "+#{line_number} #{file_name}"
          end
        end
      end

      # Get the name of the binary that Pry.config.editor points to.
      #
      # This is useful for deciding which flags we pass to the editor as
      # we can just use the program's name and ignore any absolute paths.
      #
      # @example
      #   Pry.config.editor="/home/conrad/bin/textmate -w"
      #   editor_name
      #   # => textmate
      #
      def editor_name
        File.basename(Pry.config.editor).split(" ").first
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
      def unindent(text)
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

        text.gsub(/^#{margin}/, '')
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
    end

  end
end
