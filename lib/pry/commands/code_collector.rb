class Pry
  module Command::CodeCollector
    include Helpers::CommandHelpers

    def options(opt)
      opt.on :l, :lines, "Restrict to a subset of lines. Takes a line number or range.", :optional_argument => true, :as => Range, :default => 1..-1
      opt.on :o, :out, "Select lines from Pry's output result history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1
      opt.on :i, :in, "Select lines from Pry's input expression history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1
      opt.on :s, :super, "Select the 'super' method. Can be repeated to traverse the ancestors.", :as => :count
      opt.on :d=, :doc=, "Select lines from the code object's documentation."
    end

    def content
      return @content if @content
      raise CommandError, "Only one of --out, --in, --doc and CODE_OBJECT may be specified." if bad_option_combination?

      content = case
                when opts.present?(:o)
                  pry_output_content
                when opts.present?(:i)
                  pry_input_content
                when opts.present?(:d)
                  code_object_docs
                else
                  code_object_source_or_file
                end

      @content ||= restrict_to_lines(content, line_range)
    end

    def bad_option_combination?
      [opts.present?(:in), opts.present?(:out), opts.present?(:d),
       !args.empty?].count(true) > 1
    end

    def pry_output_content
      pry_array_content_as_string(_pry_.output_array, opts[:o]) do |v|
        Pry.config.gist.inspecter.call(v)
      end
    end

    def pry_input_content
      pry_array_content_as_string(_pry_.input_array, opts[:i]) { |v| v }
    end

    def pry_array_content_as_string(array, range, &block)
      raise CommandError, "Minimum value for range is 1, not 0." if convert_to_range(range).first == 0

      array = Array(array[range]) || []
      array.each_with_object("") { |v, o| o << block.call(v) }
    end

    def code_object(str=obj_name)
      Pry::CodeObject.lookup(str, target, _pry_, :super => opts[:super])
    end

    def code_object_docs
      if co = code_object(opts[:d])
        co.doc
      else
        could_not_locate(opts[:d])
      end
    end

    def code_object_source_or_file
      (code_object && code_object.source) || file_content
    end

    def file_content
      if File.exists?(obj_name)
        File.read(obj_name)
      else
        could_not_locate(obj_name)
      end
    end

    def line_range
      opts.present?(:lines) ? one_index_range_or_number(opts[:lines]) : 0..-1
    end

    def restrict_to_lines(content, range)
      Array(content.lines.to_a[range]).join
    end

    def could_not_locate(name)
      raise CommandError, "Cannot locate: #{name}!"
    end

    def convert_to_range(n)
      if !n.is_a?(Range)
        (n..n)
      else
        n
      end
    end

    # This can be overriden by subclasses which can define what to return
    # When no arg is given, i.e `play -l 1..10` the lack of an explicit
    # code object arg defaults to `_pry_.last_file` (since that's how
    # `play` implements `no_arg`).
    def no_arg
      nil
    end

    def obj_name
      @obj_name ||= args.empty? ? no_arg : args.join(" ")
    end
  end
end
