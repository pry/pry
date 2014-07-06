require_relative 'helper'
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
    it "does not record duplicated lines" do
      Pry.history << '3'
      Pry.history << '_ += 1'
      Pry.history << '_ += 1'
      Pry.history.to_a.grep('_ += 1').count.should == 1
    end

    it "does not record empty lines" do
      c = Pry.history.to_a.count
      Pry.history << ''
      Pry.history.to_a.count.should == c
    end
  end

  describe "#clear" do
    before do
      @old_file = Pry.config.history.file
      @hist_file_path = File.expand_path('spec/fixtures/pry_history')
      Pry.config.history.file = @hist_file_path
      Pry.history.clear
      Pry.history.restore_default_behavior
      Pry.load_history
    end

    after do
      Pry.config.history.file = @old_file
    end

    it "clears this session's history" do
      Pry.history.to_a.size.should > 0
      Pry.history.clear
      Pry.history.to_a.size.should == 0
    end

    it "doesn't affect the contents of the history file" do
      Pry.history.to_a.size.should == 3
      Pry.history.clear

      File.open(@hist_file_path, 'r') { |fh|
        file = fh.to_a

        file.length.should == 3
        file.any? { |a| a =~ /athos/ }.should == true
      }
    end
  end

  describe "#history_line_count" do
    it "counts entries in history" do
      Pry.history.clear
      saved_history = "olgierd\ngustlik\njanek\ngrzes\ntomek\n"
      Pry.history.loader = proc do |&blk|
        saved_history.lines.each { |l| blk.call(l) }
      end
      Pry.load_history

      Pry.history.history_line_count.should == 5
    end
  end

  describe "#restore_default_behavior" do
    it "restores loader" do
      Pry.history.loader = proc {}
      Pry.history.restore_default_behavior
      Pry.history.loader.class.should == Method
      Pry.history.loader.name.to_sym.should == :read_from_file
    end

    it "restores saver" do
      Pry.history.saver = proc {}
      Pry.history.restore_default_behavior
      Pry.history.saver.class.should == Method
      Pry.history.saver.name.to_sym.should == :save_to_file
    end

    it "restores pusher" do
      Pry.history.pusher = proc {}
      Pry.history.restore_default_behavior
      Pry.history.pusher.class.should == Method
      Pry.history.pusher.name.to_sym.should == :push_to_readline
    end

    it "restores clearer" do
      Pry.history.clearer = proc {}
      Pry.history.restore_default_behavior
      Pry.history.clearer.class.should == Method
      Pry.history.clearer.name.to_sym.should == :clear_readline
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
    it "reads the contents of the file" do
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

    it "saves lines to a file as they are written" do
      @history.push "5"
      File.read(@histfile.path).should == "5\n"
    end

    it "interleaves lines from many places" do
      @history.push "5"
      File.open(@histfile.path, 'a'){ |f| f.puts "6" }
      @history.push "7"

      File.read(@histfile.path).should == "5\n6\n7\n"
    end
  end

  describe "expanding the history file path" do
    before { Pry.config.history.should_save = true  }
    after  { Pry.config.history.should_save = false }

    it "recognizes ~ (#1262)" do
      # This is a pretty dumb way of testing this, but at least it shouldn't
      # succeed spuriously.
      history = Pry::History.new(file_path: '~/test_history')
      error = Class.new(RuntimeError)

      File.expects(:open).
        with("#{ENV['HOME']}/test_history", 'a', 0600).
        raises(error)

      -> { history.push 'a line' }.should.raise(error)
    end
  end
end
