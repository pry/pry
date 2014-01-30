require 'helper'

describe Pry::Config do
  describe "reserved keys" do
    before do
      @config = Pry::Config.from_hash({}, nil)
    end

    it "raises an ArgumentError on assignment of a reserved key" do
      Pry::Config::RESERVED_KEYS.each do |key|
        should.raise(ArgumentError) { @config[key] = 1 }
      end
    end
  end

  describe "local config" do
    it "should be set" do
      t = pry_tester
      t.eval "_pry_.config.foobar = 'hello'"
      t.eval("_pry_.config.foobar").should == 'hello'
    end

    it "should be set (array)" do
      t = pry_tester
      t.eval "_pry_.config.foobar = []"
      t.eval "_pry_.config.foobar << 1 << 2"
      t.eval("_pry_.config.foobar").should == [1, 2]
    end

    it "should be global config value when local config is not set" do
      Pry.config.foobar = 'hello'
      t = pry_tester
      t.eval("_pry_.config.foobar").should == 'hello'
      Pry.config.foobar = nil
    end

    it "should be local config value when local config is set" do
      Pry.config.foobar = 'hello'
      t = pry_tester
      t.eval "_pry_.config.foobar = 'goodbye'"
      t.eval("_pry_.config.foobar").should == 'goodbye'
      Pry.config.foobar = nil
    end
  end

  describe "global config" do
    it "should be set" do
      Pry.config.foobar = 'hello'
      Pry.config.foobar.should == 'hello'
      Pry.config.foobar = nil
    end

    it "should be set (array)" do
      Pry.config.foobar = []
      Pry.config.foobar << 1 << 2
      Pry.config.foobar.should == [1, 2]
      Pry.config.foobar = nil
    end

    it "should keep value when local config is set" do
      Pry.config.foobar = 'hello'
      t = pry_tester
      t.eval "_pry_.config.foobar = 'goodbye'"
      Pry.config.foobar.should == 'hello'
      Pry.config.foobar = nil
    end

    it "should keep value when local config is set (array)" do
      Pry.config.foobar = [1, 2]
      t = pry_tester
      t.eval "_pry_.config.foobar << 3 << 4"
      Pry.config.foobar.should == [1, 2]
      Pry.config.foobar = nil
    end
  end
end
