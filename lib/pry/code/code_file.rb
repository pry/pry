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

    # @return [Symbol] The type of code stored in this wrapper.
    attr_reader :code_type

    # @param [String] filename The name of a file with code to be detected
    # @param [Symbol] code_type The type of code the `filename` contains
    def initialize(filename, code_type = type_from_filename(filename))
      @filename = filename
      @code_type = code_type
    end

    # @return [String] The code contained in the current `@filename`.
    def code
      if @filename == Pry.eval_path
        Pry.line_buffer.drop(1)
      elsif Pry::Method::Patcher.code_for(@filename)
        Pry::Method::Patcher.code_for(@filename)
      elsif RbxPath.is_core_path?(@filename)
        File.read(RbxPath.convert_path_to_full(@filename))
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
      find_abs_path(filename) or
      raise MethodSource::SourceNotFoundError, "Cannot open #{filename.inspect} for reading."
    end

    def find_abs_path(filename)
      code_path(filename).detect { |path| readable?(path) }
    end

    # @param [String] path
    # @return [Boolean] if the path, with or without the default ext,
    # is a readable file then `true`, otherwise `false`.
    def readable?(path)
      File.readable?(path) && !File.directory?(path) or
      File.readable?(path << DEFAULT_EXT)
    end

    # @return [Array] All the paths that contain code that Pry can use for its
    #   API's. Skips directories.
    def code_path(filename)
      [File.expand_path(filename, Dir.pwd),
       File.expand_path(filename, Pry::INITIAL_PWD),
       *$LOAD_PATH.map { |path| File.expand_path(filename, path) }]
    end

    # @param [String] filename
    # @param [Symbol] default (:unknown) the file type to assume if none could be
    #   detected.
    # @return [Symbol, nil] The CodeRay type of a file from its extension, or
    #   `nil` if `:unknown`.
    def type_from_filename(filename, default = :unknown)
      _, @code_type = EXTENSIONS.find do |k, _|
        k.any? { |ext| ext == File.extname(filename) }
      end

      code_type || default
    end

  end
end
