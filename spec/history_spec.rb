require 'helper'
require 'tempfile'

describe Pry do
  before do
    Pry.history.clear

    @saved_history = "1\n2\n3\n"

    Pry.history.loader = proc do |&blk|
      @saved_history.lines.each { |l| blk.call(l) }
    end

    Pry.load_history
  end

  after do
    Pry.history.clear
    Pry.history.restore_default_behavior
    Pry.history.instance_variable_set(:@original_lines, 0)
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

  describe "#session_line_count" do
    it "returns the number of lines in history from just this session" do
      Pry.history << 'you?'
      Pry.history << 'you are so precious'
      Pry.history.session_line_count.should == 2
    end
  end

  describe ".load_history" do
    it "should read the contents of the file" do
      Pry.history.to_a[-2..-1].should == %w(2 3)
    end
  end

  describe "saving to a file" do
    before do
      @histfile = Tempfile.new(["pryhistory", "txt"])
      @history = Pry::History.new(:file_path => @histfile.path)
      Pry.config.history.should_save = true
      @history.pusher = proc{ }
    end

    after do
      @histfile.close(true)
      Pry.config.history.should_save = false
    end

    it "should save lines to a file as they are written" do
      @history.push "5"
      File.read(@histfile.path).should == "5\n"
    end

    it "should interleave lines from many places" do
      @history.push "5"
      File.open(@histfile.path, 'a'){ |f| f.puts "6" }
      @history.push "7"

      File.read(@histfile.path).should == "5\n6\n7\n"
    end
  end
end
