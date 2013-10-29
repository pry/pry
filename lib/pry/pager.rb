require 'pry/terminal'

# A Pry::Pager is an IO-like object that accepts text and either prints it
# immediately, prints it one page at a time, or streams it to an external
# program to print one page at a time.
class Pry::Pager
  class StopPaging < StandardError
  end

  # @param [String] text
  #   A piece of text to run through a pager.
  # @param [Symbol?] pager_type
  #   `:simple` -- Use the pure ruby pager.
  #   `:system` -- Use the system pager (less) or the environment variable
  #                $PAGER if set.
  #   `nil`     -- Infer what pager to use from the environment.  What this
  #                really means is that JRuby and systems that do not have
  #                access to 'less' will run through the pure ruby pager.
  def self.page(text, pager_type = nil)
    pager = best_available($stdout, pager_type)
    pager << text
  ensure
    pager.close if pager
  end

  def self.best_available(output, pager_type = nil)
    case pager_type
    when nil
      no_pager = !SystemPager.available?
      if no_pager || Pry::Helpers::BaseHelpers.jruby?
        SimplePager.new(output)
      else
        SystemPager.new(output)
      end
    when :simple
      SimplePager.new(output)
    when :system
      SystemPager.new(output)
    else
      raise "'#{pager}' is not a recognized pager."
    end
  end

  def self.page_size
    Pry::Terminal.height!
  end

  def initialize(out)
    @out = out
  end

  def page_size
    @page_size ||= self.class.page_size
  end

  def puts(str)
    print "#{str.chomp}\n"
  end

  def write(str)
    @out.write str
  end

  def print(str)
    write str
  end
  alias << print

  def close
    # no-op for base pager, but important for subclasses
  end

  class SimplePager < Pry::Pager
    # Window height minus the number of lines used by the info bar.
    def self.page_size
      super - 3
    end

    def initialize(*)
      super
      @lines_printed = 0
    end

    def write(str)
      page_size = self.class.page_size

      str.lines.each do |line|
        @out.write line
        @lines_printed += 1 if line.end_with?("\n")

        if @lines_printed >= page_size
          @out.puts "\n<page break> --- Press enter to continue " \
                    "( q<enter> to break ) --- <page break>"
          raise StopPaging if $stdin.gets.chomp == "q"
          @lines_printed = 0
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
      @pager = IO.popen(SystemPager.default_pager, 'w')
    end

    def write(str)
      @pager.write str
    rescue Errno::EPIPE
    end

    def close
      @pager.close if @pager
    end
  end
end
