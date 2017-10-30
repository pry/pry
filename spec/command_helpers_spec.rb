require_relative 'helper'

describe Pry::Helpers::Command do
  before do
    @helper = Pry::Helpers::Command
  end

  describe "unindent" do
    it "should remove the same prefix from all lines" do
      expect(@helper.unindent(" one\n two\n")).to eq("one\ntwo\n")
    end

    it "should not be phased by empty lines" do
      expect(@helper.unindent(" one\n\n two\n")).to eq("one\n\ntwo\n")
    end

    it "should only remove a common prefix" do
      expect(@helper.unindent("  one\n two\n")).to eq(" one\ntwo\n")
    end

    it "should also remove tabs if present" do
      expect(@helper.unindent("\tone\n\ttwo\n")).to eq("one\ntwo\n")
    end

    it "should ignore lines starting with --" do
      expect(@helper.unindent(" one\n--\n two\n")).to eq("one\n--\ntwo\n")
    end
  end
end
