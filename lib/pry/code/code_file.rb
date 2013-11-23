class Pry
  class CodeFile
    DEFAULT_EXT = '.rb'

    # List of all supported languages.
    # @return [Hash]
    EXTENSIONS = {
      %w(.py)        => :python,
      %w(.js)        => :javascript,
      %w(.css)       => :css,
      %w(.xml)       => :xml,
      %w(.php)       => :php,
      %w(.html)      => :html,
      %w(.diff)      => :diff,
      %w(.java)      => :java,
      %w(.json)      => :json,
      %w(.c .h)      => :c,
      %w(.rhtml)     => :rhtml,
      %w(.yaml .yml) => :yaml,
      %w(.cpp .hpp .cc .h cxx) => :cpp,
      %w(.rb .ru .irbrc .gemspec .pryrc) => :ruby,
    }

    attr_reader :code_type

    def initialize(filename, code_type = type_from_filename(filename))
      @filename = filename
      @code_type = code_type
    end

    def code
      if @filename == Pry.eval_path
        Pry.line_buffer.drop(1)
      elsif Pry::Method::Patcher.code_for(@filename)
        Pry::Method::Patcher.code_for(@filename)
      elsif RbxPath.is_core_path?(@filename)
        File.read(RbxPath.convert_path_to_full(filename))
      else
        abs_path = abs_path(@filename)
        @code_type = type_from_filename(abs_path)
        File.read(abs_path)
      end
    end

    private

    # @param [String] filename
    # @raise [MethodSource::SourceNotFoundError] if the `filename` is not
    #   readable for some reason.
    # @return [String] absolute path for the given `filename`.
    def abs_path(filename)
      find_abs_path(filename) or raise MethodSource::SourceNotFoundError,
      "Cannot open #{filename.inspect} for reading."
    end

    def find_abs_path(filename)
      code_path(filename).detect { |path| readable_source?(path) }.tap do |path|
        path << DEFAULT_EXT if path && !File.exist?(path)
      end
    end

    def readable_source?(path)
      File.readable?(path) || File.readable?(path + DEFAULT_EXT)
    end

    def code_path(filename)
      normalized_load_path = $LOAD_PATH.map { |path|
        File.expand_path(filename, path).tap do |p|
          if File.directory?(p)
            p << DEFAULT_EXT
          end
        end
      }

      [ File.expand_path(filename, Dir.pwd),
        File.expand_path(filename, Pry::INITIAL_PWD),
        *normalized_load_path ]
    end


    # Guess the CodeRay type of a file from its extension, or nil if
    # unknown.
    #
    # @param [String] filename
    # @param [Symbol] default (:unknown) the file type to assume if none could be
    #   detected.
    # @return [Symbol, nil]
    def type_from_filename(filename, default = :unknown)
      _, @code_type = EXTENSIONS.find do |k, _|
        k.any? { |ext| ext == File.extname(filename) }
      end

      code_type || default
    end

  end
end
