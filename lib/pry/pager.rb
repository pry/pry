class Pry::Pager
  def self.page_size
    27
  end

  def self.page(text, pager = nil)
    case pager
    when nil
      is_jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
      is_jruby ? SimplePager.new(text).page : SystemPager.new(text).page
    when :simple
      SimplePager.new(text).page
    when :system
      SystemPager.new(text).page
    else
      raise "'#{pager}' is not a recongized pager."
    end
  end

  def page
    raise NotImplementedError, "#{self.class} does not implement #page."
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
