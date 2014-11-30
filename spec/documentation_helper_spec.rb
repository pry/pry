require_relative 'helper'

describe Pry::Helpers::DocumentationHelpers do
  before do
    @helper = Pry::Helpers::DocumentationHelpers
  end

  describe "get_comment_content" do
    it "should strip off the hash and unindent" do
      expect(@helper.get_comment_content(" # hello\n # world\n")).to eq("hello\nworld\n")
    end

    it "should strip out leading lines of hashes" do
      expect(@helper.get_comment_content("###############\n#hello\n#world\n")).to eq("hello\nworld\n")
    end

    it "should remove shebangs" do
      expect(@helper.get_comment_content("#!/usr/bin/env ruby\n# This is a program\n")).to eq("This is a program\n")
    end

    it "should unindent past separators" do
      expect(@helper.get_comment_content(" # Copyright Me <me@cirw.in>\n #--\n # So there.\n")).to eq("Copyright Me <me@cirw.in>\n--\nSo there.\n")
    end
  end

  describe "process_rdoc" do
    before do
      Pry.config.color = true
    end

    after do
      Pry.config.color = false
    end

    it "should syntax highlight indented code" do
      expect(@helper.process_rdoc("  4 + 4\n")).not_to eq("  4 + 4\n")
    end

    it "should highlight words surrounded by +s" do
      expect(@helper.process_rdoc("the +parameter+")).to match(/the \e.*parameter\e.*/)
    end

    it "should syntax highlight things in backticks" do
      expect(@helper.process_rdoc("for `Example`")).to match(/for `\e.*Example\e.*`/)
    end

    it "should emphasise em tags" do
      expect(@helper.process_rdoc("for <em>science</em>")).to eq("for \e[1mscience\e[0m")
    end

    it "should emphasise italic tags" do
      expect(@helper.process_rdoc("for <i>science</i>")).to eq("for \e[1mscience\e[0m")
    end

    it "should syntax highlight code in <code>" do
      expect(@helper.process_rdoc("for <code>Example</code>")).to match(/for \e.*Example\e.*/)
    end

    it "should not double-highlight backticks inside indented code" do
      expect(@helper.process_rdoc("  `echo 5`")).to match(/echo 5/)
    end

    it "should not remove ++" do
      expect(@helper.process_rdoc("--\n  comment in a bubble\n++")).to match(/\+\+/)
    end
  end

end
