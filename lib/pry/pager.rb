class Pry::Pager
  # @param [String] text
  #   A piece of text to run through a pager.
  # @param [Symbol?] pager
  #   `:simple` -- Use the pure ruby pager.
  #   `:system` -- Use the system pager (less) or the environment variable
  #                $PAGER if set.
  #   `nil`     -- Infer what pager to use from the environment.  What this
  #                really means is that JRuby and systems that do not have
  #                access to 'less' will run through the pure ruby pager.
  # @param [TrueClass,FalseClass?] tail
  #   `true`    -- Start the pager at the end of the text.
  #   `false`   -- Start the pager at the beginning (DEFAULT)
  def self.page(text, pager = nil, tail = false)
    case pager
    when nil
      no_pager = !SystemPager.available?
      is_jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      (is_jruby || no_pager) ? SimplePager.new(text).page : SystemPager.new(text).page(tail)
    when :simple
      SimplePager.new(text).page 
    when :system
      SystemPager.new(text).page(tail)
    else
      raise "'#{pager}' is not a recongized pager."
    end
  end

  def self.page_size
    27
  end

  def initialize(text)
    @text = text
  end

  class SimplePager < Pry::Pager
    def page()
      text_array = @text.lines.to_a
      text_array.each_slice(Pry::Pager.page_size) do |chunk|
        puts chunk.join
        break if chunk.size < Pry::Pager.page_size
        if text_array.size > Pry::Pager.page_size
          puts "\n<page break> --- Press enter to continue ( q<enter> to break ) --- <page break>"
          break if $stdin.gets.chomp == "q"
        end
      end
    end
  end

  class SystemPager < Pry::Pager
    def self.default_pager
      ENV["PAGER"] || "less -R -S -F -X"
    end

    def self.available?
      pager_executable = default_pager.split(' ').first
      `which #{ pager_executable }`
    rescue
    end

    def initialize(*)
      super
      @pager = SystemPager.default_pager
    end

    def page(tail=false)
      IO.popen(@pager + ((tail) ? ' +G' : ''), 'w') do |io|
        io.write @text
      end
    end
  end
end
