class Pry
  module Helpers

    module CommandHelpers

      module_function

      def meth_name_from_binding(b)
        meth_name = b.eval('__method__')
        if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
          nil
        else
          meth_name
        end
      end

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

      def is_a_dynamically_defined_method?(meth)
        file, _ = meth.source_location
        !!(file =~ /(\(.*\))|<.*>/)
      end

      def check_for_dynamically_defined_method(meth)
        file, _ = meth.source_location
        if file =~ /(\(.*\))|<.*>/ && file != Pry.eval_path
          raise "Cannot retrieve source for dynamically defined method."
        end
      end

      # Open a temp file and yield it to the block, closing it after
      # @return [String] The path of the temp file
      def temp_file
        file = Tempfile.new(["tmp", ".rb"])
        yield file
        file.path
      ensure
        file.close
      end

      ########### RBX HELPERS #############
      def is_core_rbx_path?(path)
        rbx? &&
          path.start_with?("kernel")
      end

      def rbx_core?(meth)
          meth.source_location &&
          is_core_rbx_path?(meth.source_location.first)
      end

      def rvm_ruby?(path)
        !!(path =~ /\.rvm/)
      end

      def rbx_core_code_for(meth)
        rbx_core_code_or_doc_for(meth, :code)
      end

      def rbx_core_doc_for(meth)
        rbx_core_code_or_doc_for(meth, :doc)
      end

      def rbx_core_code_or_doc_for(meth, code_or_doc)
        path_line = rbx_core_path_line_for(meth)

        case code_or_doc
        when :code
          MethodSource.source_helper(path_line)
        when :doc
          MethodSource.comment_helper(path_line)
        end
      end

      def rbx_convert_path_to_full(path)
        if rvm_ruby?(Rubinius::BIN_PATH)
          rbx_rvm_convert_path_to_full(path)
        else
          rbx_std_convert_path_to_full(path)
        end
      end

      def rbx_rvm_convert_path_to_full(path)
          ruby_name = File.dirname(Rubinius::BIN_PATH).split("/").last
          source_path = File.join(File.dirname(File.dirname(File.dirname(Rubinius::BIN_PATH))),  "src", ruby_name)
        file_name = File.join(source_path, path)
        raise "Cannot find rbx core source" if !File.exists?(file_name)
        file_name
      end

      def rbx_std_convert_path_to_full(path)
        file_name = File.join(Rubinius::BIN_PATH, "..", path)
        raise "Cannot find rbx core source" if !File.exists?(file_name)
        file_name
      end

      def rbx_core_path_line_for(meth)
        if rvm_ruby?(Rubinius::BIN_PATH)
          rvm_rbx_core_path_line_for(meth)
        else
          std_rbx_core_path_line_for(meth)
        end
      end

      def std_rbx_core_path_line_for(meth)
        file_name  = rbx_std_convert_path_to_full(meth.source_location.first)
        start_line = meth.source_location.last

        [file_name, start_line]
      end

      def rvm_rbx_core_path_line_for(meth)
        file_name  = rbx_rvm_convert_path_to_full(meth.source_location.first)
        start_line = meth.source_location.last

        [file_name, start_line]
      end

      ######### END RBX HELPERS ###############

      def code_and_code_type_for(meth)
        case code_type = code_type_for(meth)
        when nil
          return nil
        when :c
          code = Pry::MethodInfo.info_for(meth).source
          code = strip_comments_from_c_code(code)
        when :ruby
          if meth.source_location.first == Pry.eval_path
            start_line = meth.source_location.last

            # FIXME this line below needs to be refactored, WAY too
            # much of a hack. We pass nothing to prompt because if
            # prompt uses #inspect (or #pretty_inspect) on the context
            # it can hang the session if the object being inspected on
            # is enormous see: https://github.com/pry/pry/issues/245
            p = Pry.new(:input => StringIO.new(Pry.line_buffer[start_line..-1].join), :prompt => proc {""}, :hooks => {}).r(target)
            code = strip_leading_whitespace(p)
          else
            if rbx_core?(meth)
              code = strip_leading_whitespace(rbx_core_code_for(meth))
            else
              code = strip_leading_whitespace(meth.source)
            end
          end
          set_file_and_dir_locals(path_line_for(meth).first)
        end

        [code, code_type]
      end

      def doc_and_code_type_for(meth)
        case code_type = code_type_for(meth)
        when nil
          return nil
        when :c
          doc = Pry::MethodInfo.info_for(meth).docstring
        when :ruby
          if rbx_core?(meth)
            doc = strip_leading_hash_and_whitespace_from_ruby_comments(rbx_core_doc_for(meth))
          else
            doc = strip_leading_hash_and_whitespace_from_ruby_comments(meth.comment)
          end
          set_file_and_dir_locals(path_line_for(meth).first)
        end

        [doc, code_type]
      end

      def get_method_object(meth_name, target=nil, options={})
        get_method_object_from_target(*get_method_attributes(meth_name, target, options)) rescue nil
      end

      def get_method_attributes(meth_name, target=nil, options={})
        if meth_name
          if meth_name =~ /(\S+)\#(\S+)\Z/
            context, meth_name = $1, $2
            target = Pry.binding_for(target.eval(context))
            type = :instance
          elsif meth_name =~ /(\S+)\.(\S+)\Z/
            context, meth_name = $1, $2
            target = Pry.binding_for(target.eval(context))
            type = :singleton
          elsif options["instance_methods"]
            type = :instance
          elsif options[:methods]
            type = :singleton
          else
            type = nil
          end
        else
          meth_name = meth_name_from_binding(target)
          type = nil
        end
        [meth_name, target, type]
      end

      def get_method_object_from_target(meth_name, target, type=nil)
        case type
        when :instance
          target.eval("instance_method(:#{meth_name})") rescue nil
        when :singleton
          target.eval("method(:#{meth_name})") rescue nil
        else
          get_method_object_from_target(meth_name, target, :instance) ||
            get_method_object_from_target(meth_name, target, :singleton)
        end
      end

      def path_line_for(meth)
        if rbx_core?(meth)
          rbx_core_path_line_for(meth)
        else
          meth.source_location
        end
      end

      def make_header(meth, code_type, content)
        num_lines = "Number of lines: #{Pry::Helpers::Text.bold(content.each_line.count.to_s)}"
        case code_type
        when :ruby
          file, line = path_line_for(meth)
          "\n#{Pry::Helpers::Text.bold('From:')} #{file} @ line #{line}:\n#{num_lines}\n\n"
        else
          file = Pry::MethodInfo.info_for(meth).file
          "\n#{Pry::Helpers::Text.bold('From:')} #{file} in Ruby Core (C Method):\n#{num_lines}\n\n"
        end
      end

      def is_a_c_method?(meth)
        meth.source_location.nil?
      end

      def should_use_pry_doc?(meth)
        Pry.config.has_pry_doc && is_a_c_method?(meth)
      end

      def code_type_for(meth)
        # only C methods
        if should_use_pry_doc?(meth)
          info = Pry::MethodInfo.info_for(meth)
          if info && info.source
            code_type = :c
          else
            output.puts "Cannot find C method: #{meth.name}"
            code_type = nil
          end
        else
          if is_a_c_method?(meth)
            output.puts "Cannot locate this method: #{meth.name}. Try `gem install pry-doc` to get access to Ruby Core documentation."
            code_type = nil
          else
            check_for_dynamically_defined_method(meth)
            code_type = :ruby
          end
        end
        code_type
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

      # strip leading whitespace but preserve indentation
      def strip_leading_whitespace(text)
        return text if text.empty?
        leading_spaces = text.lines.first[/^(\s+)/, 1]
        text.gsub(/^#{leading_spaces}/, '')
      end

      def strip_leading_hash_and_whitespace_from_ruby_comments(comment)
        comment = comment.dup
        comment.gsub!(/\A\#+?$/, '')
        comment.gsub!(/^\s*#/, '')
        strip_leading_whitespace(comment)
      end

      def strip_comments_from_c_code(code)
        code.sub(/\A\s*\/\*.*?\*\/\s*/m, '')
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
            run ".#{editor_invocation}"
          end
        else
          run ".#{editor_invocation}"
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
