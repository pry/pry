require 'helper'
require 'tempfile'

describe Pry do
  before do
    Pry.history.clear

    @saved_history = "1\n2\n3\n"

    Pry.history.loader = proc do |&blk|
      @saved_history.lines.each { |l| blk.call(l) }
    end

    Pry.history.saver = proc do |lines|
      @saved_history << lines.map { |l| "#{l}\n" }.join
    end

    Pry.load_history
  end

  after do
    Pry.history.clear
    Pry.history.restore_default_behavior
  end

  describe '#push' do
    it "should not record duplicated lines" do
      Pry.history << '3'
      Pry.history << '_ += 1'
      Pry.history << '_ += 1'
      Pry.history.to_a.grep('_ += 1').count.should == 1
    end

    it "should not record empty lines" do
      c = Pry.history.to_a.count
      Pry.history << ''
      Pry.history.to_a.count.should == c
    end
  end

  describe ".load_history" do
    it "should read the contents of the file" do
      Pry.history.to_a[-2..-1].should == %w(2 3)
    end
  end

  describe ".save_history" do
    it "should include a trailing newline" do
      Pry.history << "4"
      Pry.save_history
      @saved_history.should =~ /4\n\z/
    end

    it "should not change anything if history is not changed" do
      @saved_history = "4\n5\n6\n"
      Pry.save_history
      @saved_history.should == "4\n5\n6\n"
    end

    it "should append new lines to the file" do
      Pry.history << "4"
      Pry.save_history
      @saved_history.should == "1\n2\n3\n4\n"
    end

    it "should not clobber lines written by other Pry's in the meantime" do
      Pry.history << "5"
      @saved_history << "4\n"
      Pry.save_history

      Pry.history.to_a[-3..-1].should == ["2", "3", "5"]
      @saved_history.should == "1\n2\n3\n4\n5\n"
    end

    it "should not delete lines from the file if this session's history was cleared" do
      Pry.history.clear
      Pry.save_history
      @saved_history.should == "1\n2\n3\n"
    end

    it "should save new lines that are added after the history was cleared" do
      Pry.history.clear
      Pry.history << "4"
      Pry.save_history
      @saved_history.should =~ /1\n2\n3\n4\n/
    end

    it "should only append new lines the second time it is saved" do
      Pry.history << "4"
      Pry.save_history
      @saved_history << "5\n"
      Pry.history << "6"
      Pry.save_history

      Pry.history.to_a[-4..-1].should == ["2", "3", "4", "6"]
      @saved_history.should == "1\n2\n3\n4\n5\n6\n"
    end
  end
end
