class Pry
  # The History class is responsible for maintaining the user's input history, both
  # internally and within Readline.
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
      @loader  = method(:read_from_file)
      @pusher  = method(:push_to_readline)
      @clearer = method(:clear_readline)
    end

    # Load the input history using `History.loader`.
    # @return [Integer] The number of lines loaded
    def load
      @loader.call do |line|
        Readline::HISTORY << line.chomp
        @history << line.chomp
      end
    end

    # Add a line to the input history, ignoring blank and duplicate lines.
    # @param [String] line
    # @return [String] The same line that was passed in
    def push(line)
      unless line.empty? || (@history.last && line == @history.last)
        @pusher.call(line)
        @history << line
        @history_file.puts line if save_history?
      end
      line
    end
    alias << push

    # Clear all history. Anything the user entered before this point won't be
    # saved, but anything they put in afterwards will still be appended to the
    # history file on exit.
    def clear
      @clearer.call
      @history = []
    end

    # @return [Fixnum] The number of lines in history.
    def history_line_count
      @history.count
    end

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
      begin
        history_file = File.expand_path(Pry.config.history.file)
        if File.exists?(history_file)
          File.foreach(history_file) { |line| yield(line) }
        end
      rescue => error
        unless error.message.empty?
          warn "History file not loaded, received an error: #{error.message}"
        end
      end
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

    # The history file for appending
    def history_file
      if @history_file.nil?
        begin
          @history_file ||= File.open(file_path, 'a')
          @history_file.sync = true
        rescue Errno::EACCES
          # We should probably create an option Pry.show_warnings?!?!?!
          warn 'Unable to write to your history file, history not saved'
          @history_file = false
        end
      end
      @history_file
    end

    def save_history?
      Pry.config.history.should_save && history_file
    end

    def file_path
      @file_path || Pry.config.history.file
    end
  end
end
