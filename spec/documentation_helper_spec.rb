require 'helper'

describe Pry::Helpers::DocumentationHelpers do
  before do
    @helper = Pry::Helpers::DocumentationHelpers
  end

  describe "get_comment_content" do
    it "should strip off the hash and unindent" do
      @helper.get_comment_content(" # hello\n # world\n").should == "hello\nworld\n"
    end

    it "should strip out leading lines of hashes" do
      @helper.get_comment_content("###############\n#hello\n#world\n").should == "hello\nworld\n"
    end

    it "should remove shebangs" do
      @helper.get_comment_content("#!/usr/bin/env ruby\n# This is a program\n").should == "This is a program\n"
    end

    it "should unindent past separators" do
      @helper.get_comment_content(" # Copyright Me <me@cirw.in>\n #--\n # So there.\n").should == "Copyright Me <me@cirw.in>\n--\nSo there.\n"
    end
  end

  describe "process_rdoc" do
    before do
      Pry.color = true
    end

    after do
      Pry.color = false
    end

    it "should syntax highlight indented code" do
      @helper.process_rdoc("  4 + 4\n").should.not == "  4 + 4\n"
    end

    it "should highlight words surrounded by +s" do
      @helper.process_rdoc("the +parameter+").should =~ /the \e.*parameter\e.*/
    end

    it "should syntax highlight things in backticks" do
      @helper.process_rdoc("for `Example`").should =~ /for `\e.*Example\e.*`/
    end

    it "should emphasise em tags" do
      @helper.process_rdoc("for <em>science</em>").should == "for \e[1mscience\e[0m"
    end

    it "should emphasise italic tags" do
      @helper.process_rdoc("for <i>science</i>").should == "for \e[1mscience\e[0m"
    end

    it "should syntax highlight code in <code>" do
      @helper.process_rdoc("for <code>Example</code>").should =~ /for \e.*Example\e.*/
    end

    it "should not double-highlight backticks inside indented code" do
      @helper.process_rdoc("  `echo 5`").should =~ /echo 5/
    end

    it "should not remove ++" do
      @helper.process_rdoc("--\n  comment in a bubble\n++").should =~ /\+\+/
    end

    it "should do nothing if Pry.color is false" do
      Pry.color = false
      @helper.process_rdoc("  4 + 4\n").should == "  4 + 4\n"
    end
  end

end