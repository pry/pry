require 'helper'

describe Pry::Helpers::CommandHelpers do
  before do
    @helper = Pry::Helpers::CommandHelpers
  end

  describe "unindent" do
    it "should remove the same prefix from all lines" do
      @helper.unindent(" one\n two\n").should == "one\ntwo\n"
    end

    it "should not be phased by empty lines" do
      @helper.unindent(" one\n\n two\n").should == "one\n\ntwo\n"
    end

    it "should only remove a common prefix" do
      @helper.unindent("  one\n two\n").should == " one\ntwo\n"
    end

    it "should also remove tabs if present" do
      @helper.unindent("\tone\n\ttwo\n").should == "one\ntwo\n"
    end

    it "should ignore lines starting with --" do
      @helper.unindent(" one\n--\n two\n").should == "one\n--\ntwo\n"
    end
  end
end
