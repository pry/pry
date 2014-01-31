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

  describe "traversal to parent" do
    it "traverses back to the parent when a local key is not found" do
      config = Pry::Config.new Pry::Config.from_hash(foo: 1)
      config.foo.should == 1
    end

    it "stores a local key and prevents traversal to the parent" do
      config = Pry::Config.new Pry::Config.from_hash(foo: 1)
      config.foo = 2
      config.foo.should == 2
    end

    it "duplicates a copy on read from the parent" do
      ukraine = "i love"
      config = Pry::Config.new Pry::Config.from_hash(home: ukraine)
      config.home.equal?(ukraine).should == false
    end

    it "forgets a local copy in favor of the parent's new value" do
      default = Pry::Config.from_hash(shoes: "and socks")
      local = Pry::Config.new(default).tap(&:shoes)
      default.shoes = 1
      local.shoes.should == "and socks"
      local.forget(:shoes)
      local.shoes.should == 1
    end
  end

  describe "#[]=" do
    it "stores keys as strings" do
      local = Pry::Config.from_hash({})
      local[:zoo] = "hello"
      local.to_hash.should == { "zoo" => "hello" }
    end
  end
end
