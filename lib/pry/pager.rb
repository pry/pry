class Pry::Pager
  def self.page_size
    27
  end

  def initialize(text, io)
    @text = text
    @out = io
  end

  def page
    text_array = @text.lines.to_a
    text_array.each_slice(Pry::Pager.page_size) do |chunk|
      @out.puts chunk.join
      break if chunk.size < Pry::Pager.page_size
      if text_array.size > Pry::Pager.page_size
        @out.puts "\n<page break> --- Press enter to continue ( q<enter> to break ) --- <page break>"
        break if $stdin.gets.chomp == "q"
      end
    end
  end
end
