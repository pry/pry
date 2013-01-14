class Pry
  module Gist
    DESCRIPTION = 'Upload code, docs, history to https://gist.github.com/'
    INVOCATIONS = {
      :method   => ['gist -m my_method', 'gist the method my_method' ],
      :doc      => ['gist -d my_method', 'gist the docs for my_method' ],
      :input    => ['gist -i 1..2', 'gist the input expressions from 1 to 2' ],
      :kommand  => ['gist -k show-method', 'gists pry command show-method' ],
      :class    => ['gist -c Pry::Method', 'gist the Pry::Method class' ],
      :jist     => ['jist -c Pry::Method', 'alias for the above' ],
      :lines    => ['gist -m my_method --lines 2..-2', 'limit by range' ],
      :cliponly => ['gist -m my_method --clip', 'copy (but do not gist)' ],
      :clipit   => ['clipit -m my_method', 'alias for the above' ],
      # TODO:
      # :var      =>
      # :hist     =>
      # :file     =>
    }
    class << self
      def example_code sym; INVOCATIONS[sym][0] end
      def example_description sym; INVOCATIONS[sym][1] end
      def examples_docs
        INVOCATIONS.keys.map do |e|
          "e.g.: %-33s # %s " % [example_code(e), example_description(e)]
        end.join "\n"
      end
      def require_jist; require 'jist' end
    end
  end

  class Command::Gist < Pry::ClassCommand
    include Pry::Helpers::DocumentationHelpers

    match 'gist'
    group 'Misc'
    description Pry::Gist::DESCRIPTION
    command_options :requires_gem => 'jist', :shellwords => false

banner <<BANNER
Usage: gist [options]

#{Pry::Gist::DESCRIPTION}

If you would like to associate your gists with your GitHub account, run `gist --login`.

#{Pry::Gist.examples_docs}
BANNER

    attr_accessor :content, :filename

    def setup
      Pry::Gist.require_jist # extracted so test can stub out
      @content = ''
    end

    def from_pry_api api_obj
      @content << api_obj.source << "\n"
      @filename = api_obj.source_file
    end

    def options(opt)
      ext ='ruby'
      opt.on :login, "Authenticate the jist gem with GitHub"
      opt.on :d, :doc, "Gist a method's documentation", :argument => true do |meth_name|
        meth = get_method_or_raise(meth_name, target, {})
        text.no_color do
          @content << process_comment_markup(meth.doc) << "\n"
        end
        @filename = meth.source_file + ".doc"
      end
      opt.on :m, :method, "Gist a method's source", :argument => true do |meth_name|
        from_pry_api get_method_or_raise(meth_name, target, {})
      end
      opt.on :k, :command, "Gist a command's source", :argument => true do |command_name|
        command = find_command(command_name)
        from_pry_api Pry::Method.new(command.block)
      end
      opt.on :c, :class, "Gist a class or module's source", :argument => true do |class_name|
        from_pry_api Pry::WrappedModule.from_str(class_name, target)
      end
      opt.on :var, "Gist a variable's content", :argument => true do |variable_name|
        begin
          obj = target.eval(variable_name)
        rescue Pry::RescuableException
          raise CommandError, "Gist failed: Invalid variable name: #{variable_name}"
        end

        @content << Pry.config.gist.inspecter.call(obj) << "\n"
      end
      opt.on :hist, "Gist a range of Readline history lines",  :optional_argument => true, :as => Range, :default => -20..-1 do |range|
        h = Pry.history.to_a
        @content << h[one_index_range(convert_to_range(range))].join("\n") << "\n"
      end

      opt.on :f, :file, "Gist a file.", :argument => true do |file|
        @content << File.read(File.expand_path(file)) << "\n"
        @filename = file
      end
      opt.on :o, :out, "Gist entries from Pry's output result history. Takes an index or range", :optional_argument => true,
      :as => Range, :default => -1 do |range|
        range = convert_to_range(range)

        range.each do |v|
          @content << Pry.config.gist.inspecter.call(_pry_.output_array[v])
        end

        @content << "\n"
      end
      opt.on :clip, "Copy the selected content to clipboard instead, do NOT gist it", :default => false
      opt.on :p, :public, "Create a public gist (default: false)", :default => false
      opt.on :l, :lines, "Only gist a subset of lines from the gistable content", :optional_argument => true, :as => Range, :default => 1..-1
      opt.on :i, :in, "Gist entries from Pry's input expression history. Takes an index or range", :optional_argument => true,
      :as => Range, :default => -1 do |range|
        range = convert_to_range(range)
        input_expressions = _pry_.input_array[range] || []
        Array(input_expressions).each_with_index do |code, index|
          corrected_index = index + range.first
          if code && code != ""
            @content << code
            if code !~ /;\Z/
              @content << "#{comment_expression_result_for_gist(Pry.config.gist.inspecter.call(_pry_.output_array[corrected_index]))}"
            end
          end
        end
      end
    end

    def process
      return Jist.login! if opts.present?(:login)

      if @content =~ /\A\s*\z/
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
      Jist.copy(@content)
      output.puts "Copied content to clipboard!"
    end

    def perform_gist
      if opts.present?(:lines)
        @content = restrict_to_lines(content, opts[:l])
      end

      response = Jist.gist(content, :filename => filename_or_fake,
                                    :public => !!opts[:p])

      if response
        url = response['html_url']
        Jist.copy(url)
        output.puts 'Gist created at URL, which is now in the clipboard: ', url
      end
    end

    def filename_or_fake
      case @filename
      when nil
        'anonymous.rb' # not sure what triggers this condition
      when '(pry)'
        'repl.rb'
      else
        File.basename(@filename)
      end
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

  end

  Pry::Commands.add_command(Pry::Command::Gist)
  Pry::Commands.alias_command 'clipit', 'gist --clip'
  Pry::Commands.alias_command 'jist', 'gist'
end
