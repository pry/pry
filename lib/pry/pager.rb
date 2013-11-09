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
      if no_pager || Pry::Helpers::BaseHelpers.jruby?
        SimplePager.new(text).page
      else
        SystemPager.new(text).page
      end
    when :simple
      SimplePager.new(text).page
    when :system
      SystemPager.new(text).page
    else
      raise "'#{pager}' is not a recognized pager."
    end
  end

  def self.page_size
    @page_size ||= Pry::Terminal.height!
  end

  def initialize(text)
    @text = text
  end

  class SimplePager < Pry::Pager
    def page
      # The pager size minus the number of lines used by the simple pager info bar.
      page_size = Pry::Pager.page_size - 3
      text_array = @text.lines.to_a

      text_array.each_slice(page_size) do |chunk|
        puts chunk.join
        break if chunk.size < page_size
        if text_array.size > page_size
          puts "\n<page break> --- Press enter to continue ( q<enter> to break ) --- <page break>"
          break if Readline.readline.chomp == "q"
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
