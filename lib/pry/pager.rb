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
  def self.page(text, pager = nil)
    case pager
    when nil
      no_pager = !SystemPager.available?
      is_jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      (is_jruby || no_pager) ? SimplePager.new(text).page : SystemPager.new(text).page
    when :simple
      SimplePager.new(text).page
    when :system
      SystemPager.new(text).page
    else
      raise "'#{pager}' is not a recognized pager."
    end
  end

  def self.page_size
    @page_size ||= begin
      require 'io/console'
      $stdout.winsize.first
    rescue LoadError
      27
    end
  end

  def initialize(text)
    @text = text
  end

  class SimplePager < Pry::Pager
    def page
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
      pager = ENV["PAGER"] || ""

      # Default to less, and make sure less is being passed the correct options
      if pager.strip.empty? or pager =~ /^less\s*/
        pager = "less -R -S -F -X"
      end

      pager
    end

    def self.available?
      if @system_pager.nil?
        @system_pager = begin
          pager_executable = default_pager.split(' ').first
          `which #{ pager_executable }`
        rescue
          false
        end
      else
        @system_pager
      end
    end

    def initialize(*)
      super
      @pager = SystemPager.default_pager
    end

    def page
      IO.popen(@pager, 'w') do |io|
        io.write @text
      end
    end
  end
end
