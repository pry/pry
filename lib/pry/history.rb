class Pry
  # The History class is responsible for maintaining the user's input history, both
  # internally and within Readline::HISTORY.
  class History
    def initialize
      @history = []
      @saved_lines = 0
    end

    # Loads a file's contents into the input history.
    # @param [String] filename
    # @return [Integer] The number of lines loaded
    def load(filename)
      File.foreach(filename) do |line|
        Readline::HISTORY << line.chomp
        @history << line.chomp
      end
      @saved_lines = @history.length
    end

    # Appends input history from this session to a file.
    # @param [String] filename
    # @return [Integer] The number of lines saved
    def save(filename)
      history_to_save = @history[@saved_lines..-1]
      File.open(filename, 'a') do |f|
        history_to_save.each { |ln| f.puts ln }
      end
      @saved_lines = @history.length
      history_to_save.length
    end

    # Adds a line to the input history, ignoring blank and duplicate lines.
    # @param [String] line
    # @return [String] The same line that was passed in
    def push(line)
      unless line.empty? || (@history.last && line == @history.last)
        Readline::HISTORY << line
        @history << line
      end
      line
    end
    alias << push

    # Clears all history. Anything the user entered before this point won't be
    # saved, but anything they put in afterwards will still be appended to the
    # history file on exit.
    def clear
      Readline::HISTORY.shift until Readline::HISTORY.empty?
      @history = []
      @saved_lines = 0
    end

    # Returns an Array containing all stored history.
    # @return [Array<String>] An Array containing all lines of history loaded
    #   or entered by the user in the current session.
    def to_a
      @history.dup
    end
  end
end
