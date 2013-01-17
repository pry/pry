class Pry::TerminalInfo
  # Return a pair of [rows, columns] which gives the size of the window.
  #
  # If the window size cannot be determined, return nil.
  def self.screen_size
    rows, cols = actual_screen_size
    if rows && cols
      [rows.to_i, cols.to_i]
    else
      nil
    end
  end

  # Return a screen width or a default if it fails.
  def self.width! default = 80
    (screen_size || [nil, default])[1]
  end

  def self.actual_screen_size
    [
      # Some readlines also provides get_screen_size.
      # Readline comes before IO#winsize because jruby sometimes defaults winsize to [25, 80]
      readline_screen_size,

      # io/console adds a winsize method to IO streams.
      # rescue nil for jruby 1.7.0 [jruby/jruby#354]
      $stdout.tty? && $stdout.respond_to?(:winsize) && ($stdout.winsize rescue nil),

      # Otherwise try to use the environment (this may be out of date due
      # to window resizing, but it's better than nothing).
      [ENV["LINES"] || ENV["ROWS"], ENV["COLUMNS"]],

      # If the user is running within ansicon, then use the screen size
      # that it reports (same caveats apply as with ROWS and COLUMNS)
      ENV['ANSICON'] =~ /\((.*)x(.*)\)/ && [$2, $1],
    ].detect do |(_, cols)|
      cols.to_i > 0
    end
  end

  def self.readline_screen_size
    Readline.get_screen_size if Readline.respond_to?(:get_screen_size)
  rescue Java::JavaLang::NullPointerException
    # This rescue won't happen on jrubies later than:
    #     https://github.com/jruby/jruby/pull/436
    nil
  end
end
