class Pry
  module DefaultCommands
    Gist = Pry::CommandSet.new do
      create_command "gist", "Gist a method or expression history to github.", :requires_gem => "jist" do
        include Pry::Helpers::DocumentationHelpers

        banner <<-USAGE
          Usage: gist [OPTIONS] [METH]
          Gist method (doc or source) or input expression to github.
          Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
          e.g: gist -m my_method       # gist the method my_method
          e.g: gist -d my_method       # gist the documentation for my_method
          e.g: gist -i 1..10           # gist the input expressions from 1 to 10
          e.g: gist -k show-method     # gist the command show-method
          e.g: gist -c Pry             # gist the Pry class
          e.g: gist -m hello_world --lines 2..-2    # gist from lines 2 to the second-last of the hello_world method
          e.g: gist -m my_method --clip             # Copy my_method source to clipboard, do not gist it.
        USAGE

        command_options :shellwords => false

        attr_accessor :content
        attr_accessor :code_type

        def setup
          require 'jist'
          self.content   = ""
          self.code_type = :ruby
        end

        def options(opt)
          opt.on :m, :method, "Gist a method's source.", :argument => true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            self.content << meth.source << "\n"
            self.code_type = meth.source_type
          end
          opt.on :d, :doc, "Gist a method's documentation.", :argument => true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            text.no_color do
              self.content << process_comment_markup(meth.doc, self.code_type) << "\n"
            end
            self.code_type = :plain
          end
          opt.on :k, :command, "Gist a command's source.", :argument => true do |command_name|
            command = find_command(command_name)
            block = Pry::Method.new(command.block)
            self.content << block.source << "\n"
          end
          opt.on :c, :class, "Gist a class or module's source.", :argument => true do |class_name|
            mod = Pry::WrappedModule.from_str(class_name, target)
            self.content << mod.source << "\n"
          end
          opt.on :var, "Gist a variable's content.", :argument => true do |variable_name|
            begin
              obj = target.eval(variable_name)
            rescue Pry::RescuableException
              raise CommandError, "Gist failed: Invalid variable name: #{variable_name}"
            end

            self.content << Pry.config.gist.inspecter.call(obj) << "\n"
          end
          opt.on :hist, "Gist a range of Readline history lines.",  :optional_argument => true, :as => Range, :default => -20..-1 do |range|
            h = Pry.history.to_a
            self.content << h[one_index_range(convert_to_range(range))].join("\n") << "\n"
          end

          opt.on :f, :file, "Gist a file.", :argument => true do |file|
            self.content << File.read(File.expand_path(file)) << "\n"
          end
          opt.on :o, :out, "Gist entries from Pry's output result history. Takes an index or range.", :optional_argument => true,
          :as => Range, :default => -1 do |range|
            range = convert_to_range(range)

            range.each do |v|
              self.content << Pry.config.gist.inspecter.call(_pry_.output_array[v])
            end

            self.content << "\n"
          end
          opt.on :clip, "Copy the selected content to clipboard instead, do NOT gist it.", :default => false
          opt.on :p, :public, "Create a public gist (default: false)", :default => false
          opt.on :l, :lines, "Only gist a subset of lines from the gistable content.", :optional_argument => true, :as => Range, :default => 1..-1
          opt.on :i, :in, "Gist entries from Pry's input expression history. Takes an index or range.", :optional_argument => true,
          :as => Range, :default => -1 do |range|
            range = convert_to_range(range)
            input_expressions = _pry_.input_array[range] || []
            Array(input_expressions).each_with_index do |code, index|
              corrected_index = index + range.first
              if code && code != ""
                self.content << code
                if code !~ /;\Z/
                  self.content << "#{comment_expression_result_for_gist(Pry.config.gist.inspecter.call(_pry_.output_array[corrected_index]))}"
                end
              end
            end
          end
        end

        def process
          if self.content =~ /\A\s*\z/
            raise CommandError, "Found no code to gist."
          end

          if opts.present?(:clip)
            perform_clipboard
          else
            perform_gist
          end
        end

        # copy content to clipboard instead (only used with --clip flag)
        def perform_clipboard
          copy(self.content)
          output.puts "Copied content to clipboard!"
        end

        def perform_gist
          type_map = { :ruby => "rb", :c => "c", :plain => "plain" }

          extname = opts.present?(:file) ? ".#{gist_file_extension(opts[:f])}" : ".#{type_map[self.code_type]}"

          if opts.present?(:lines)
            self.content = restrict_to_lines(content, opts[:l])
          end

          response = Jist.gist(self.content, :filename => extname,
                                         :public => !!opts[:p])

          if response
            copy(response['html_url'])
            output.puts "Gist created at #{response['html_url']} and added to clipboard."
          end
        end

        def gist_file_extension(file_name)
          file_name.split(".").last
        end

        def convert_to_range(n)
          if !n.is_a?(Range)
            (n..n)
          else
            n
          end
        end

        def comment_expression_result_for_gist(result)
          content = ""
          result.lines.each_with_index do |line, index|
            if index == 0
              content << "# => #{line}"
            else
              content << "#    #{line}"
            end
          end
          content
        end

        # Copy a string to the clipboard.
        #
        # @param [String] content
        #
        # @copyright Copyright (c) 2008 Chris Wanstrath (MIT)
        # @see https://github.com/defunkt/gist/blob/master/lib/gist.rb#L178
        def copy(content)
          cmd = case true
          when system("type pbcopy > /dev/null 2>&1")
            :pbcopy
          when system("type xclip > /dev/null 2>&1")
            :xclip
          when system("type putclip > /dev/null 2>&1")
            :putclip
          end

          if cmd
            IO.popen(cmd.to_s, 'r+') { |clip| clip.print content }
          end

          content
        end
      end

      alias_command "clipit", "gist --clip"
    end
  end
end
