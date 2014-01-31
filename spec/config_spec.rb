require 'helper'

describe Pry::Config do
  describe "reserved keys" do
    it "raises an ArgumentError on assignment of a reserved key" do
      local = Pry::Config.from_hash({})
      Pry::Config::RESERVED_KEYS.each do |key|
        should.raise(ArgumentError) { local[key] = 1 }
      end
    end
  end

  describe "traversal to parent" do
    it "traverses back to the parent when a local key is not found" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      local.foo.should == 1
    end

    it "stores a local key and prevents traversal to the parent" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      local.foo = 2
      local.foo.should == 2
    end

    it "duplicates a copy on read from the parent" do
      ukraine = "i love"
      local = Pry::Config.new Pry::Config.from_hash(home: ukraine)
      local.home.equal?(ukraine).should == false
    end

    it "forgets a local copy in favor of the parent's new value" do
      default = Pry::Config.from_hash(shoes: "and socks")
      local = Pry::Config.new(default).tap(&:shoes)
      default.shoes = 1
      local.shoes.should == "and socks"
      local.forget(:shoes)
      local.shoes.should == 1
    end

    it "traverses through a chain of parents" do
      root = Pry::Config.from_hash({foo: 21})
      local1 = Pry::Config.new(root)
      local2 = Pry::Config.new(local1)
      local3 = Pry::Config.new(local2)
      local3.foo.should == 21
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
