class Pry
  class History
    def initialize
      @history = []
      @first_new_line = 0 # TODO: rename this
    end

    def load(filename)
      File.foreach(filename) do |line|
        Readline::HISTORY << line.chomp
        @history << line.chomp
      end
      @first_new_line = @history.length
    end

    def save(filename)
      history_to_save = @history[@first_new_line..-1]
      File.open(filename, 'a') do |f|
        history_to_save.each { |ln| f.puts ln }
      end
      @first_new_line = @history.length
    end

    def push(line)
      line = line.to_s
      unless line.empty? || (@history.last && line.strip == @history.last.strip)
        Readline::HISTORY << line
        @history << line
      end
      line
    end
    alias << push

    def clear
      Readline::HISTORY.shift until Readline::HISTORY.empty?
      @history = []
      @first_new_line = 0
    end

    def to_a
      @history.dup
    end
  end
end
