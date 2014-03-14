class Pry
  # The History class is responsible for maintaining the user's input history,
  # both internally and within Readline.
  class History
    attr_accessor :loader, :saver, :pusher, :clearer

    # @return [Fixnum] Number of lines in history when Pry first loaded.
    attr_reader :original_lines

    def initialize(options={})
      @history = []
      @original_lines = 0
      @file_path = options[:file_path]
      restore_default_behavior
    end

    # Assign the default methods for loading, saving, pushing, and clearing.
    def restore_default_behavior
      Pry.config.input # force Readline to load if applicable

      @loader = method(:read_from_file)
      @saver  = method(:save_to_file)

      if defined?(Readline)
        @pusher  = method(:push_to_readline)
        @clearer = method(:clear_readline)
      else
        @pusher  = proc { }
        @clearer = proc { }
      end
    end

    # Load the input history using `History.loader`.
    # @return [Integer] The number of lines loaded
    def load
      @loader.call do |line|
        @pusher.call(line.chomp)
        @history << line.chomp
        @original_lines += 1
      end
    end

    # Add a line to the input history, ignoring blank and duplicate lines.
    # @param [String] line
    # @return [String] The same line that was passed in
    def push(line)
      unless line.empty? || (@history.last && line == @history.last)
        @pusher.call(line)
        @history << line
        @saver.call(line) if Pry.config.history.should_save
      end
      line
    end
    alias << push

    # Clear this session's history. This won't affect the contents of the
    # history file.
    def clear
      @clearer.call
      @history = []
      @original_lines = 0
    end

    # @return [Fixnum] The number of lines in history.
    def history_line_count
      @history.count
    end

    # @return [Fixnum] The number of lines in history from just this session.
    def session_line_count
      @history.count - @original_lines
    end

    # Return an Array containing all stored history.
    # @return [Array<String>] An Array containing all lines of history loaded
    #   or entered by the user in the current session.
    def to_a
      @history.dup
    end

    private

    # The default loader. Yields lines from `Pry.history.config.file`.
    def read_from_file
      filename = File.expand_path(Pry.config.history.file)

      if File.exists?(filename)
        File.foreach(filename) { |line| yield(line) }
      end
    rescue => error
      warn "History file not loaded: #{error.message}"
    end

    # The default pusher. Appends the given line to Readline::HISTORY.
    # @param [String] line
    def push_to_readline(line)
      Readline::HISTORY << line
    end

    # The default clearer. Clears Readline::HISTORY.
    def clear_readline
      Readline::HISTORY.shift until Readline::HISTORY.empty?
    end

    # The default saver. Appends the given line to `Pry.history.config.file`.
    def save_to_file(line)
      history_file.puts line if history_file
    end

    # The history file, opened for appending.
    def history_file
      if defined?(@history_file)
        @history_file
      else
        @history_file = File.open(file_path, 'a', 0600).tap { |f| f.sync = true }
      end
    rescue Errno::EACCES
      warn 'History not saved; unable to open your history file for writing.'
      @history_file = false
    end

    def file_path
      @file_path || Pry.config.history.file
    end
  end
end
