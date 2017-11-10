require_relative 'helper'
describe Pry::Config do
  describe "bug #1552" do
    specify "a local key has precendence over its default when the stored value is false" do
      local = Pry::Config.from_hash({}, Pry::Config.from_hash('color' => true))
      local.color = false
      expect(local.color).to eq(false)
    end
  end

  describe "bug #1277" do
    specify "a local key has precendence over an inherited method of the same name" do
      local = Pry::Config.from_hash(output: 'foobar')
      local.extend Module.new { def output(); 'broken'; end }
      expect(local.output).to eq('foobar')
    end
  end

  describe "reserved keys" do
    it "raises Pry::Config::ReservedKeyError on assignment of a reserved key" do
      local = Pry::Config.new
      local.instance_variable_get(:@reserved_keys).each do |key|
        expect { local[key] = 1 }.to raise_error(Pry::Config::ReservedKeyError)
      end
    end
  end

  describe "traversal to parent" do
    it "traverses back to the parent when a local key is not found" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      expect(local.foo).to eq(1)
    end

    it "stores a local key and prevents traversal to the parent" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      local.foo = 2
      expect(local.foo).to eq(2)
    end

    it "traverses through a chain of parents" do
      root = Pry::Config.from_hash({foo: 21})
      local1 = Pry::Config.new(root)
      local2 = Pry::Config.new(local1)
      local3 = Pry::Config.new(local2)
      expect(local3.foo).to eq(21)
    end

    it "stores a local copy of the parents hooks upon accessing them" do
      parent = Pry::Config.from_hash(hooks: "parent_hooks")
      local  = Pry::Config.new parent
      local.hooks.gsub! 'parent', 'local'
      expect(local.hooks).to eq 'local_hooks'
      expect(parent.hooks).to eq('parent_hooks')
    end
  end

  describe ".from_hash" do
    it "returns an object without a default" do
      local = Pry::Config.from_hash({})
      expect(local.default).to eq(nil)
    end

    it "returns an object with a default" do
      default = Pry::Config.new(nil)
      local = Pry::Config.from_hash({}, default)
      expect(local.default).to eq(local)
    end

    it "recursively builds Pry::Config objects from a Hash" do
      h = {'foo1' => {'foo2' => {'foo3' => 'foobar'}}}
      default = Pry::Config.from_hash(h)
      expect(default.foo1).to be_instance_of(described_class)
      expect(default.foo1.foo2).to be_instance_of(described_class)
    end
  end


  describe "#respond_to_missing?" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "returns a Method object for a dynamic key" do
      @config["key"] = 1
      method_obj = @config.method(:key)
      expect(method_obj.name).to eq :key
      expect(method_obj.call).to eq(1)
    end

    it "returns a Method object for a setter on a parent" do
      config = described_class.from_hash({}, described_class.from_hash(foo: 1))
      expect(config.method(:foo=)).to be_an_instance_of(Method)
    end
  end

  describe "#respond_to?" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "returns true for a local key" do
      @config.zzfoo = 1
      expect(@config.respond_to?(:zzfoo)).to eq(true)
    end

    it "returns false for an unknown key" do
      expect(@config.respond_to?(:blahblah)).to eq(false)
    end
  end

  describe "#default" do
    it "returns nil" do
      local = Pry::Config.new(nil)
      expect(local.default).to eq(nil)
    end

    it "returns the default" do
      default = Pry::Config.new(nil)
      local = Pry::Config.new(default)
      expect(local.default).to eq(default)
    end
  end

  describe "#keys" do
    it "returns an array of local keys" do
      root = Pry::Config.from_hash({zoo: "boo"}, nil)
      local = Pry::Config.from_hash({foo: "bar"}, root)
      expect(local.keys).to eq(["foo"])
    end
  end

  describe "#==" do
    it "compares equality through the underlying lookup table" do
      local1 = Pry::Config.new(nil)
      local2 = Pry::Config.new(nil)
      local1.foo = "hi"
      local2.foo = "hi"
      expect(local1).to eq(local2)
    end

    it "compares equality against an object who does not implement #to_hash" do
      local1 = Pry::Config.new(nil)
      expect(local1).not_to eq(Object.new)
    end
  end

  describe "#forget" do
    it "forgets a local key" do
      local = Pry::Config.new Pry::Config.from_hash(foo: 1)
      local.foo = 2
      expect(local.foo).to eq 2
      local.forget(:foo)
      expect(local.foo).to eq(1)
    end
  end

  describe "#to_hash" do
    it "provides a copy of local key & value pairs as a Hash" do
      local = Pry::Config.new Pry::Config.from_hash(bar: true)
      local.foo = "21"
      expect(local.to_hash).to eq({ "foo" => "21" })
    end

    it "returns a duplicate of the lookup table" do
      local = Pry::Config.new(nil)
      local.to_hash.merge!("foo" => 42)
      expect(local.foo).not_to eq(42)
    end
  end

  describe "#merge!" do
    before do
      @config = Pry::Config.new(nil)
    end

    it "merges an object who returns a Hash through #to_hash" do
      obj = Class.new { def to_hash() {epoch: 1} end }.new
      @config.merge!(obj)
      expect(@config.epoch).to eq(1)
    end

    it "merges an object who returns a Hash through #to_h" do
      obj = Class.new { def to_h() {epoch: 2} end }.new
      @config.merge!(obj)
      expect(@config.epoch).to eq(2)
    end

    it "merges a Hash" do
      @config.merge!(epoch: 420)
      expect(@config.epoch).to eq(420)
    end

    it "raises a TypeError for objects who can't become a Hash" do
      expect { @config.merge!(Object.new) }.to raise_error TypeError
    end
  end

  describe "#clear" do
    before do
      @local = Pry::Config.new(nil)
    end

    it "returns true" do
      expect(@local.clear).to eq(true)
    end

    it "clears local assignments" do
      @local.foo = 1
      @local.clear
      expect(@local.to_hash).to eq({})
    end
  end

  describe "#[]=" do
    it "stores keys as strings" do
      local = Pry::Config.from_hash({})
      local[:zoo] = "hello"
      expect(local.to_hash).to eq({ "zoo" => "hello" })
    end
  end

  describe "#[]" do
    it "traverses back to a default" do
      default = Pry::Config.from_hash({k: 1})
      local = Pry::Config.new(default)
      expect(local['k']).to eq(1)
    end

    it "traverses back to a default (2 deep)" do
      default1 = Pry::Config.from_hash({k: 1})
      default2 = Pry::Config.from_hash({}, default1)
      local = Pry::Config.new(default2)
      expect(local['k']).to eq(1)
    end

    it "traverses back to a default that doesn't exist, and returns nil" do
      local = Pry::Config.from_hash({}, nil)
      expect(local['output']).to eq(nil)
    end
  end
end
