require_relative 'helper'
describe Pry::Config do
  describe "reserved keys" do
    it "raises an ArgumentError on assignment of a reserved key" do
      local = Pry::Config.new
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

    it "traverses through a chain of parents" do
      root = Pry::Config.from_hash({foo: 21})
      local1 = Pry::Config.new(root)
      local2 = Pry::Config.new(local1)
      local3 = Pry::Config.new(local2)
      local3.foo.should == 21
    end
  end

  describe ".from_hash" do
    it "returns an object without a default" do
      local = Pry::Config.from_hash({})
      local.default.should == nil
    end

    it "returns an object with a default" do
      default = Pry::Config.new(nil)
      local = Pry::Config.from_hash({}, default)
      local.default.should == local
    end
  end


  describe "#respond_to_missing?" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "returns a Method object for a dynamic key" do
      @config["key"] = 1
      method_obj = @config.method(:key)
      method_obj.name.should == :key
      method_obj.call.should == 1
    end
  end

  describe "#respond_to?" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "returns true for a local key" do
      @config.zzfoo = 1
      @config.respond_to?(:zzfoo).should == true
    end

    it "returns false for an unknown key" do
      @config.respond_to?(:blahblah).should == false
    end
  end

  describe "#default" do
    it "returns nil" do
      local = Pry::Config.new(nil)
      local.default.should == nil
    end

    it "returns the default" do
      default = Pry::Config.new(nil)
      local = Pry::Config.new(default)
      local.default.should == default
    end
  end

  describe "#keys" do
    it "returns an array of local keys" do
      root = Pry::Config.from_hash({zoo: "boo"}, nil)
      local = Pry::Config.from_hash({foo: "bar"}, root)
      local.keys.should == ["foo"]
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

    it "compares equality against an object who does not implement #to_hash" do
      local1 = Pry::Config.new(nil)
      local1.should.not == Object.new
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

    it "returns a duplicate of the lookup table" do
      local = Pry::Config.new(nil)
      local.to_hash.merge!("foo" => 42)
      local.foo.should.not == 42
    end
  end

  describe "#merge!" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "merges an object who returns a Hash through #to_hash" do
      obj = Class.new { def to_hash() {epoch: 1} end }.new
      @config.merge!(obj)
      @config.epoch.should == 1
    end

    it "merges an object who returns a Hash through #to_h" do
      obj = Class.new { def to_h() {epoch: 2} end }.new
      @config.merge!(obj)
      @config.epoch.should == 2
    end

    it "merges a Hash" do
      @config.merge!(epoch: 420)
      @config.epoch.should == 420
    end

    it "raises a TypeError for objects who can't become a Hash" do
      should.raise(TypeError) { @config.merge!(Object.new) }
    end
  end

  describe "#clear" do
    before do
      @local = Pry::Config.new(nil)
    end

    it "returns true" do
      @local.clear.should == true
    end

    it "clears local assignments" do
      @local.foo = 1
      @local.clear
      @local.to_hash.should == {}
    end

    it "is aliased as #refresh" do
      @local.method(:clear).should == @local.method(:refresh)
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
