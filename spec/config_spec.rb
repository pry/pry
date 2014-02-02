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

    it "traverses through a chain of parents" do
      root = Pry::Config.from_hash({foo: 21})
      local1 = Pry::Config.new(root)
      local2 = Pry::Config.new(local1)
      local3 = Pry::Config.new(local2)
      local3.foo.should == 21
    end
  end

  describe ".from_hash" do
    it "returns an object without a default when given 1 argument" do
      local = Pry::Config.from_hash({})
      local.instance_variable_get(:@default).should == nil
    end

    it "returns an object with a default when given 2 arguments" do
      default = Pry::Config.new(nil)
      local = Pry::Config.from_hash({}, default)
      local.instance_variable_get(:@default).should == default
    end
  end


  describe "#==" do
    it "compares equality through the underlying lookup table" do
      local1 = Pry::Config.new(nil)
      local2 = Pry::Config.new(nil)
      local1.foo = "hi"
      local2.foo = "hi"
      local1.should == local2
    end
  end

  describe "#forget" do
    it "forgets a local key" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      local.foo = 2
      local.foo.should == 2
      local.forget(:foo)
      local.foo.should == 1
    end
  end

  describe "#to_hash" do
    it "provides a copy of local key & value pairs as a Hash" do
      local = Pry::Config.new Pry::Config.from_hash(bar: true)
      local.foo = "21"
      local.to_hash.should == { "foo" => "21" }
    end
  end

  describe "#merge!" do
    it "can merge a Hash-like object" do
      local = Pry::Config.new(nil)
      local.merge! Pry::Config.from_hash(foo: 21)
      local.foo.should == 21
    end

    it "can merge a Hash" do
      local = Pry::Config.new(nil)
      local.merge!(foo: 21)
      local.foo.should == 21
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
