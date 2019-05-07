# frozen_string_literal: true

describe "Pry::Pager" do
  describe "PageTracker" do
    before do
      @pt = Pry::Pager::PageTracker.new(10, 10)
    end

    def record_short_line
      @pt.record "012345678\n"
    end

    def record_long_line
      @pt.record "0123456789012\n"
    end

    def record_multiline
      @pt.record "0123456789012\n01\n"
    end

    def record_string_without_newline
      @pt.record "0123456789"
    end

    def record_string_with_color_codes
      @pt.record(Pry::SyntaxHighlighter.highlight('0123456789') + "\n")
    end

    it "records short lines that don't add up to a page" do
      9.times { record_short_line }
      expect(@pt.page?).to equal false
    end

    it "records short lines that do add up to a page" do
      10.times { record_short_line }
      expect(@pt.page?).to equal true
    end

    it "treats a long line as taking up more than one row" do
      4.times { record_long_line }
      expect(@pt.page?).to equal false
      record_long_line
      expect(@pt.page?).to equal true
    end

    it "records a string with an embedded newline" do
      3.times { record_multiline }
      expect(@pt.page?).to equal false
      record_short_line
      expect(@pt.page?).to equal true
    end

    it "doesn't count a line until it ends" do
      12.times { record_string_without_newline }
      expect(@pt.page?).to equal false
      record_short_line
      expect(@pt.page?).to equal true
    end

    it "doesn't count ansi color codes towards length" do
      9.times { record_string_with_color_codes }
      expect(@pt.page?).to equal false
      record_string_with_color_codes
      expect(@pt.page?).to equal true
    end
  end
end
