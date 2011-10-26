class Pry
  module Helpers

    module CommandHelpers
      include OptionsHelpers

      module_function

      # if start_line is not false then add line numbers starting with start_line
      def render_output(should_flood, start_line, text, color=:blue)
        if start_line
          text = Pry::Helpers::Text.with_line_numbers text, start_line, color
        end

        if should_flood
          output.puts text
        else
          stagger_output(text)
        end
      end

      # Open a temp file and yield it to the block, closing it after
      # @return [String] The path of the temp file
      def temp_file
        file = Tempfile.new(["tmp", ".rb"])
        yield file
      ensure
        file.close
      end

      def get_method_or_raise(name, target, opts={}, omit_help=false)
        meth = Pry::Method.from_str(name, target, opts)

        if name && !meth
          command_error("The method '#{name}' could not be found.", omit_help)
        elsif !meth
          command_error("No method name given, and context is not a method.", omit_help)
        end

        (opts[:super] || 0).times do
          if meth.super
            meth = meth.super
          else
            command_error("The method '#{meth.name}' is not defined in a superclass of '#{class_name(meth.owner)}'.", omit_help)
          end
        end

        set_file_and_dir_locals(meth.source_file)
        meth
      end

      def command_error(message, omit_help)
        message += " Type `#{command_name} --help` for help." unless omit_help
        raise CommandError, message
      end

      def make_header(meth, content=meth.source)
        header = "\n#{Pry::Helpers::Text.bold('From:')} #{meth.source_file} "

        if meth.source_type == :c
          header << "in Ruby Core (C Method):\n"
        else
          header << "@ line #{meth.source_line}:\n"
        end

        header << "#{Pry::Helpers::Text.bold("Number of lines:")} #{content.each_line.count.to_s}\n"
      end

      def file_map
        {
          [".c", ".h"] => :c,
          [".cpp", ".hpp", ".cc", ".h", "cxx"] => :cpp,
          [".rb", "Rakefile", ".irbrc", ".gemspec", ".pryrc"] => :ruby,
          ".py" => :python,
          ".diff" => :diff,
          ".css" => :css,
          ".html" => :html,
          [".yaml", ".yml"] => :yaml,
          ".xml" => :xml,
          ".php" => :php,
          ".js" => :javascript,
          ".java" => :java,
          ".rhtml" => :rhtml,
          ".json" => :json
        }
      end

      def syntax_highlight_by_file_type_or_specified(contents, file_name, file_type)
        _, language_detected = file_map.find do |k, v|
          Array(k).any? do |matcher|
            matcher == File.extname(file_name) || matcher == File.basename(file_name)
          end
        end

        language_detected = file_type if file_type
        if Pry.color
          CodeRay.scan(contents, language_detected).term
        else
          contents
        end
      end

      # convert negative line numbers to positive by wrapping around
      # last line (as per array indexing with negative numbers)
      def normalized_line_number(line_number, total_lines)
        line_number < 0 ? line_number + total_lines : line_number
      end

      # returns the file content between the lines and the normalized
      # start and end line numbers.
      def read_between_the_lines(file_name, start_line, end_line)
        if file_name == Pry.eval_path
          content = Pry.line_buffer.drop(1).join
        else
          content = File.read(File.expand_path(file_name))
        end
        lines_array = content.each_line.to_a

        [lines_array[start_line..end_line].join, normalized_line_number(start_line, lines_array.size),
         normalized_line_number(end_line, lines_array.size)]
      end

      def process_rdoc(comment, code_type)
        comment = comment.dup
        comment.gsub(/<code>(?:\s*\n)?(.*?)\s*<\/code>/m) { Pry.color ? CodeRay.scan($1, code_type).term : $1 }.
          gsub(/<em>(?:\s*\n)?(.*?)\s*<\/em>/m) { Pry.color ? "\e[1m#{$1}\e[0m": $1 }.
          gsub(/<i>(?:\s*\n)?(.*?)\s*<\/i>/m) { Pry.color ? "\e[1m#{$1}\e[0m" : $1 }.
          gsub(/\B\+(\w*?)\+\B/)  { Pry.color ? "\e[32m#{$1}\e[0m": $1 }.
          gsub(/((?:^[ \t]+.+(?:\n+|\Z))+)/)  { Pry.color ? CodeRay.scan($1, code_type).term : $1 }.
          gsub(/`(?:\s*\n)?(.*?)\s*`/) { Pry.color ? CodeRay.scan($1, code_type).term : $1 }
      end

      def process_yardoc_tag(comment, tag)
        in_tag_block = nil
        comment.lines.map do |v|
          if in_tag_block && v !~ /^\S/
            Pry::Helpers::Text.strip_color Pry::Helpers::Text.strip_color(v)
          elsif in_tag_block
            in_tag_block = false
            v
          else
            in_tag_block = true if v =~ /^@#{tag}/
            v
          end
        end.join
      end

      def process_yardoc(comment)
        yard_tags = ["param", "return", "option", "yield", "attr", "attr_reader", "attr_writer",
                     "deprecate", "example"]
        (yard_tags - ["example"]).inject(comment) { |a, v| process_yardoc_tag(a, v) }.
          gsub(/^@(#{yard_tags.join("|")})/) { Pry.color ? "\e[33m#{$1}\e[0m": $1 }
      end

      def process_comment_markup(comment, code_type)
        process_yardoc process_rdoc(comment, code_type)
      end

      def invoke_editor(file, line)
        if Pry.config.editor.respond_to?(:call)
          editor_invocation = Pry.config.editor.call(file, line)
        else
          editor_invocation = "#{Pry.config.editor} #{start_line_syntax_for_editor(file, line)}"
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
          system(editor_invocation)
        end
      end

      # Return the syntax for a given editor for starting the editor
      # and moving to a particular line within that file
      def start_line_syntax_for_editor(file_name, line_number)
        file_name = file_name.gsub(/\//, '\\') if RUBY_PLATFORM =~ /mswin|mingw/

        # special case for 1st line
        return file_name if line_number <= 1

        case Pry.config.editor
        when /^[gm]?vi/, /^emacs/, /^nano/, /^pico/, /^gedit/, /^kate/
          "+#{line_number} #{file_name}"
        when /^mate/, /^geany/
          "-l #{line_number} #{file_name}"
        when /^uedit32/
          "#{file_name}/#{line_number}"
        when /^jedit/
          "#{file_name} +line:#{line_number}"
        else
          if RUBY_PLATFORM =~ /mswin|mingw/
            "#{file_name}"
          else
            "+#{line_number} #{file_name}"
          end
        end
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
      # @param  [String] The text from which to remove indentation
      # @return [String], The text with indentation stripped.
      #
      # @copyright Heavily based on textwrap.dedent from Python, which is:
      #   Copyright (C) 1999-2001 Gregory P. Ward.
      #   Copyright (C) 2002, 2003 Python Software Foundation.
      #   Written by Greg Ward <gward@python.net>
      #
      #   Licensed under <http://docs.python.org/license.html>
      #   From <http://hg.python.org/cpython/file/6b9f0a6efaeb/Lib/textwrap.py>
      #
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

    end

  end
end
