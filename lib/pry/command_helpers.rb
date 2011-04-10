class Pry
  class Commands < CommandBase
    module CommandHelpers 
      
      def meth_name_from_binding(b)
        meth_name = b.eval('__method__')
        if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
          nil
        else
          meth_name
        end
      end

      def set_file_and_dir_locals(file_name)
        return if !target
        $_file_temp = File.expand_path(file_name)
        $_dir_temp =  File.dirname($_file_temp)
        target.eval("_file_ = $_file_temp")
        target.eval("_dir_ = $_file_temp")
      end

      def stagger_output(text)
        page_size = 22
        text_array = text.lines.to_a
        text_array.each_slice(page_size) do |chunk|
          output.puts chunk.join
          break if chunk.size < page_size
          if text_array.size > page_size
            output.puts "\n<page break> --- Press enter to continue ( q<enter> to break ) --- <page break>" 
            break if $stdin.gets.chomp == "q"
          end
        end
      end

      def add_line_numbers(lines, start_line)
        lines.each_line.each_with_index.map do |line, idx|
          adjusted_index = idx + start_line
          if Pry.color
            cindex = CodeRay.scan("#{adjusted_index}", :ruby).term
            "#{cindex}: #{line}"
          else
            "#{idx}: #{line}"
          end
        end.join
      end

      # only add line numbers if start_line is not false
      # if start_line is not false then add line numbers starting with start_line
      def render_output(should_stagger, start_line, doc)
        if start_line
          doc = add_line_numbers(doc, start_line)
        end

        if should_stagger
          stagger_output(doc)
        else
          output.puts doc
        end
      end

      def check_for_dynamically_defined_method(meth)
        file, _ = meth.source_location
        if file =~ /(\(.*\))|<.*>/
          raise "Cannot retrieve source for dynamically defined method."
        end
      end

      def remove_first_word(text)
        text.split.drop(1).join(' ')
      end

      def get_method_object(meth_name, target, options)
        if !meth_name
          return nil
        end
 
        if options[:M]
          target.eval("instance_method(:#{meth_name})")
        elsif options[:m]
          target.eval("method(:#{meth_name})")
        else
          begin
            target.eval("instance_method(:#{meth_name})")
          rescue
            begin
              target.eval("method(:#{meth_name})")
            rescue
              return nil
            end
          end
        end
      end
      
      def make_header(meth, code_type)
        file, line = meth.source_location
        case code_type
        when :ruby
          "\nFrom #{file} @ line #{line}:\n\n"
        else
          "\nFrom Ruby Core (C Method):\n\n"
        end
      end

      def is_a_c_method?(meth)
        meth.source_location.nil?
      end

      def should_use_pry_doc?(meth)
        Pry.has_pry_doc && is_a_c_method?(meth)
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
          [".rb", "Rakefile"] => :ruby,
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
        CodeRay.scan(contents, language_detected).term
      end

      def read_between_the_lines(file_name, start_line, end_line)
        content = File.read(File.expand_path(file_name))
        content.each_line.to_a[start_line..end_line].join
      end
      
    end
  end
end
