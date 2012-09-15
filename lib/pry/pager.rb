class Pry::Pager
  #
  # @param [String] text
  #   A piece of text to run through a pager.
  #
  # @param [:simple] pager
  #   Use the pure ruby pager.
  #   
  # @param [:system] pager
  #   Use the system pager (less)
  #   
  # @param [nil] pager
  #   Infer what pager to use from the environment.
  #   What this really means is that JRuby uses the pure-ruby pager, and other
  #   platforms will use the system pager.
  #
  # @return [void]
  #
  def self.page(text, pager = nil)
    case pager
    when nil
      `less` rescue nil
      no_pager = !$?.success?
      is_jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      (is_jruby || no_pager) ? SimplePager.new(text).page : SystemPager.new(text).page
    when :simple
      SimplePager.new(text).page
    when :system
      SystemPager.new(text).page
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
    def page
      IO.popen("less -R -S -F -X", "w") do |less|
        less.puts @text
      end
    end
  end
end
