require_relative 'helper'
require 'set'

describe Pry::Method do
  it "should use String names for compatibility" do
    klass = Class.new { def hello; end }
    expect(Pry::Method.new(klass.instance_method(:hello)).name).to eq("hello")
  end

  describe ".from_str" do
    it 'should look up instance methods if no methods available and no options provided' do
      klass = Class.new { def hello; end }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      expect(meth).to eq(klass.instance_method(:hello))
    end

    it 'should look up methods if no instance methods available and no options provided' do
      klass = Class.new { def self.hello; end }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      expect(meth).to eq(klass.method(:hello))
    end

    it 'should look up instance methods first even if methods available and no options provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      expect(meth).to eq(klass.instance_method(:hello))
    end

    it 'should look up instance methods if "instance-methods"  option provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass), {"instance-methods" => true})
      expect(meth).to eq(klass.instance_method(:hello))
    end

    it 'should look up methods if :methods  option provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass), {:methods => true})
      expect(meth).to eq(klass.method(:hello))
    end

    it 'should look up instance methods using the Class#method syntax' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str("klass#hello", Pry.binding_for(binding))
      expect(meth).to eq(klass.instance_method(:hello))
    end

    it 'should look up methods using the object.method syntax' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str("klass.hello", Pry.binding_for(binding))
      expect(meth).to eq(klass.method(:hello))
    end

    it 'should NOT look up instance methods using the Class#method syntax if no instance methods defined' do
      klass = Class.new { def self.hello; end  }
      meth = Pry::Method.from_str("klass#hello", Pry.binding_for(binding))
      expect(meth).to eq(nil)
    end

    it 'should NOT look up methods using the object.method syntax if no methods defined' do
      klass = Class.new { def hello; end  }
      meth = Pry::Method.from_str("klass.hello", Pry.binding_for(binding))
      expect(meth).to eq(nil)
    end

    it 'should look up methods using klass.new.method syntax' do
      klass = Class.new { def hello; :hello; end }
      meth = Pry::Method.from_str("klass.new.hello", Pry.binding_for(binding))
      expect(meth.name).to eq("hello")
    end

    it 'should take care of corner cases like mongo[] e.g Foo::Bar.new[]- issue 998' do
      klass = Class.new { def []; :hello; end }
      meth = Pry::Method.from_str("klass.new[]", Pry.binding_for(binding))
      expect(meth.name).to eq("[]")
    end

    it 'should take care of cases like $ mongo[] - issue 998' do
      f = Class.new { def []; :hello; end }.new
      meth = Pry::Method.from_str("f[]", Pry.binding_for(binding))
      expect(meth.name).to eq("[]")
    end

    it 'should look up instance methods using klass.meth#method syntax' do
      klass = Class.new { def self.meth; Class.new; end }
      meth = Pry::Method.from_str("klass.meth#initialize", Pry.binding_for(binding))
      expect(meth.name).to eq("initialize")
    end

    it 'should look up methods using instance::bar syntax' do
      klass = Class.new{ def self.meth; Class.new; end }
      meth = Pry::Method.from_str("klass::meth", Pry.binding_for(binding))
      expect(meth.name).to eq("meth")
    end

    it 'should not raise an exception if receiver does not exist' do
      expect { Pry::Method.from_str("random_klass.meth", Pry.binding_for(binding)) }.to_not raise_error
    end
  end

  describe '.from_binding' do
    it 'should be able to pick a method out of a binding' do
      expect(Pry::Method.from_binding(Class.new{ def self.foo; binding; end }.foo).name).to eq("foo")
    end

    it 'should NOT find a method from the toplevel binding' do
      expect(Pry::Method.from_binding(TOPLEVEL_BINDING)).to eq(nil)
    end

    it "should find methods that have been undef'd" do
      c = Class.new do
        def self.bar
          class << self; undef bar; end
          binding
        end
      end

      m = Pry::Method.from_binding(c.bar)
      expect(m.name).to eq("bar")
    end

    # Our source_location trick doesn't work, due to https://github.com/rubinius/rubinius/issues/953
    unless Pry::Helpers::BaseHelpers.rbx?
       it 'should find the super method correctly' do
        a = Class.new{ def gag33; binding; end; def self.line; __LINE__; end }
        b = Class.new(a){ def gag33; super; end }

        g = b.new.gag33
        m = Pry::Method.from_binding(g)

        expect(m.owner).to eq(a)
        expect(m.source_line).to eq(a.line)
        expect(m.name).to eq("gag33")
      end
    end

    it 'should find the right method if a super method exists' do
      a = Class.new{ def gag; binding; end; }
      b = Class.new(a){ def gag; super; binding; end; def self.line; __LINE__; end }

      m = Pry::Method.from_binding(b.new.gag)

      expect(m.owner).to eq(b)
      expect(m.source_line).to eq(b.line)
      expect(m.name).to eq("gag")
    end

    # Temporarily disabled to work around rubinius/rubinius#2871.
    unless Pry::Helpers::BaseHelpers.rbx?
      it "should find the right method from a BasicObject" do
        a = Class.new(BasicObject) { def gag; ::Kernel.binding; end; def self.line; __LINE__; end }

        m = Pry::Method.from_binding(a.new.gag)
        expect(m.owner).to eq(a)
        expect(m.source_file).to eq(__FILE__)
        expect(m.source_line).to eq(a.line)
      end
    end

    it 'should find the right method even if it was renamed and replaced' do
      o = Object.new
      class << o
        def borscht
          "nips"
          binding
        end
        alias paella borscht
        def borscht() paella end
      end

      m = Pry::Method.from_binding(o.borscht)
      expect(m.source).to eq(Pry::Method(o.method(:paella)).source)
    end
  end

  describe 'super' do
    it 'should be able to find the super method on a bound method' do
      a = Class.new{ def rar; 4; end }
      b = Class.new(a){ def rar; super; end }

      obj = b.new

      zuper = Pry::Method(obj.method(:rar)).super
      expect(zuper.owner).to eq(a)
      expect(zuper.receiver).to eq(obj)
    end

    it 'should be able to find the super method of an unbound method' do
      a = Class.new{ def rar; 4; end }
      b = Class.new(a){ def rar; super; end }

      zuper = Pry::Method(b.instance_method(:rar)).super
      expect(zuper.owner).to eq(a)
    end

    it 'should return nil if no super method exists' do
      a = Class.new{ def rar; super; end }

      expect(Pry::Method(a.instance_method(:rar)).super).to eq(nil)
    end

    it 'should be able to find super methods defined on modules' do
      m = Module.new{ def rar; 4; end }
      a = Class.new{ def rar; super; end; include m }

      zuper = Pry::Method(a.new.method(:rar)).super
      expect(zuper.owner).to eq(m)
    end

    it 'should be able to find super methods defined on super-classes when there are modules in the way' do
      a = Class.new{ def rar; 4; end }
      m = Module.new{ def mooo; 4; end }
      b = Class.new(a){ def rar; super; end; include m }

      zuper = Pry::Method(b.new.method(:rar)).super
      expect(zuper.owner).to eq(a)
    end

    it 'should be able to jump up multiple levels of bound method, even through modules' do
      a = Class.new{ def rar; 4; end }
      m = Module.new{ def rar; 4; end }
      b = Class.new(a){ def rar; super; end; include m }

      zuper = Pry::Method(b.new.method(:rar)).super
      expect(zuper.owner).to eq(m)
      expect(zuper.super.owner).to eq(a)
    end
  end

  describe 'all_from_class' do
    def should_find_method(name)
      expect(Pry::Method.all_from_class(@class).map(&:name)).to include name
    end

    it 'should be able to find public instance methods defined in a class' do
      @class = Class.new{ def meth; 1; end }
      should_find_method('meth')
    end

    it 'should be able to find private and protected instance methods defined in a class' do
      @class = Class.new { protected; def prot; 1; end; private; def priv; 1; end }
      should_find_method('priv')
      should_find_method('prot')
    end

    it 'should find methods all the way up to Kernel' do
      @class = Class.new
      should_find_method('exit!')
    end

    it 'should be able to find instance methods defined in a super-class' do
      @class = Class.new(Class.new{ def meth; 1; end }) {}
      should_find_method('meth')
    end

    it 'should be able to find instance methods defined in modules included into this class' do
      @class = Class.new{ include Module.new{ def meth; 1; end; } }
      should_find_method('meth')
    end

    it 'should be able to find instance methods defined in modules included into super-classes' do
      @class = Class.new(Class.new{ include Module.new{ def meth; 1; end; } })
      should_find_method('meth')
    end

    it 'should attribute overridden methods to the sub-class' do
      @class = Class.new(Class.new{ include Module.new{ def meth; 1; end; } }) { def meth; 2; end }
      expect(Pry::Method.all_from_class(@class).detect{ |x| x.name == 'meth' }.owner).to eq(@class)
    end

    it 'should be able to find methods defined on a singleton class' do
      @class = (class << Object.new; def meth; 1; end; self; end)
      should_find_method('meth')
    end

    it 'should be able to find methods on super-classes when given a singleton class' do
      @class = (class << Class.new{ def meth; 1; end}.new; self; end)
      should_find_method('meth')
    end
  end

  describe 'all_from_obj' do
    describe 'on normal objects' do
      def should_find_method(name)
        expect(Pry::Method.all_from_obj(@obj).map(&:name)).to include name
      end

      it "should find methods defined in the object's class" do
        @obj = Class.new{ def meth; 1; end }.new
        should_find_method('meth')
      end

      it "should find methods defined in modules included into the object's class" do
        @obj = Class.new{ include Module.new{ def meth; 1; end } }.new
        should_find_method('meth')
      end

      it "should find methods defined in the object's singleton class" do
        @obj = Object.new
        class << @obj; def meth; 1; end; end
        should_find_method('meth')
      end

      it "should find methods in modules included into the object's singleton class" do
        @obj = Object.new
        @obj.extend Module.new{ def meth; 1; end }
        should_find_method('meth')
      end

      it "should find methods all the way up to Kernel" do
        @obj = Object.new
        should_find_method('exit!')
      end

      it "should not find methods defined on the classes singleton class" do
        @obj = Class.new{ class << self; def meth; 1; end; end }.new
        expect(Pry::Method.all_from_obj(@obj).map(&:name)).not_to include 'meth'
      end

      it "should work in the face of an overridden send" do
        @obj = Class.new{ def meth; 1; end; def send; raise EOFError; end }.new
        should_find_method('meth')
      end
    end

    describe 'on classes' do
      def should_find_method(name)
        expect(Pry::Method.all_from_obj(@class).map(&:name)).to include name
      end

      it "should find methods defined in the class' singleton class" do
        @class = Class.new{ class << self; def meth; 1; end; end }
        should_find_method('meth')
      end

      it "should find methods defined on modules extended into the class" do
        @class = Class.new{ extend Module.new{ def meth; 1; end; } }
        should_find_method('meth')
      end

      it "should find methods defined on the singleton class of super-classes" do
        @class = Class.new(Class.new{ class << self; def meth; 1; end; end })
        should_find_method('meth')
      end

      it "should not find methods defined within the class" do
        @class = Class.new{ def meth; 1; end }
        expect(Pry::Method.all_from_obj(@obj).map(&:name)).not_to include 'meth'
      end

      it "should find methods defined on Class" do
        @class = Class.new
        should_find_method('allocate')
      end

      it "should find methods defined on Kernel" do
        @class = Class.new
        should_find_method('exit!')
      end

      it "should attribute overridden methods to the sub-class' singleton class" do
        @class = Class.new(Class.new{ class << self; def meth; 1; end; end }) { class << self; def meth; 1; end; end }
        expect(Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'meth' }.owner).to eq(class << @class; self; end)
      end

      it "should attrbute overridden methods to the class not the module" do
        @class = Class.new { class << self; def meth; 1; end; end; extend Module.new{ def meth; 1; end; } }
        expect(Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'meth' }.owner).to eq(class << @class; self; end)
      end

      it "should attribute overridden methods to the relevant singleton class in preference to Class" do
        @class = Class.new { class << self; def allocate; 1; end; end }
        expect(Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'allocate' }.owner).to eq(class << @class; self; end)
      end
    end

    describe 'method resolution order' do
      module LS
        class Top; end

        class Next < Top; end

        module M; end
        module N; include M; end
        module O; include M; end
        module P; end

        class Low < Next; include N; include P; end
        class Lower < Low; extend N; end
        class Bottom < Lower; extend O; end
      end

      def singleton_class(obj); class << obj; self; end; end

      it "should look at a class and then its superclass" do
        expect(Pry::Method.instance_resolution_order(LS::Next)).to eq([LS::Next] + Pry::Method.instance_resolution_order(LS::Top))
      end

      it "should include the included modules between a class and its superclass" do
        expect(Pry::Method.instance_resolution_order(LS::Low)).to eq([LS::Low, LS::P, LS::N, LS::M] + Pry::Method.instance_resolution_order(LS::Next))
      end

      it "should not include modules extended into the class" do
        expect(Pry::Method.instance_resolution_order(LS::Bottom)).to eq([LS::Bottom] + Pry::Method.instance_resolution_order(LS::Lower))
      end

      it "should include included modules for Modules" do
        expect(Pry::Method.instance_resolution_order(LS::O)).to eq([LS::O, LS::M])
      end

      it "should include the singleton class of objects" do
        obj = LS::Low.new
        expect(Pry::Method.resolution_order(obj)).to eq([singleton_class(obj)] + Pry::Method.instance_resolution_order(LS::Low))
      end

      it "should not include singleton classes of numbers" do
        expect(Pry::Method.resolution_order(4)).to eq(Pry::Method.instance_resolution_order(Fixnum))
      end

      it "should include singleton classes for classes" do
        expect(Pry::Method.resolution_order(LS::Low)).to eq([singleton_class(LS::Low)] + Pry::Method.resolution_order(LS::Next))
      end

      it "should include modules included into singleton classes" do
        expect(Pry::Method.resolution_order(LS::Lower)).to eq([singleton_class(LS::Lower), LS::N, LS::M] + Pry::Method.resolution_order(LS::Low))
      end

      it "should include modules at most once" do
        expect(Pry::Method.resolution_order(LS::Bottom).count(LS::M)).to eq(1)
      end

      it "should include modules at the point which they would be reached" do
        expect(Pry::Method.resolution_order(LS::Bottom)).to eq([singleton_class(LS::Bottom), LS::O] + (Pry::Method.resolution_order(LS::Lower)))
      end

      it "should include the Pry::Method.instance_resolution_order of Class after the singleton classes" do
        expect(Pry::Method.resolution_order(LS::Top)).to eq(
          [singleton_class(LS::Top), singleton_class(Object), singleton_class(BasicObject),
           *Pry::Method.instance_resolution_order(Class)]
        )
      end
    end
  end

  describe 'method_name_from_first_line' do
    it 'should work in all simple cases' do
      meth = Pry::Method.new(nil)
      expect(meth.send(:method_name_from_first_line, "def x")).to eq("x")
      expect(meth.send(:method_name_from_first_line, "def self.x")).to eq("x")
      expect(meth.send(:method_name_from_first_line, "def ClassName.x")).to eq("x")
      expect(meth.send(:method_name_from_first_line, "def obj_name.x")).to eq("x")
    end
  end

  describe 'method aliases' do
    before do
      @class = Class.new {
        def eat
        end

        alias fress eat
        alias_method :omnomnom, :fress

        def eruct
        end
      }
    end

    it 'should be able to find method aliases' do
      meth = Pry::Method(@class.new.method(:eat))
      aliases = Set.new(meth.aliases)

      expect(aliases).to eq(Set.new(["fress", "omnomnom"]))
    end

    it 'should return an empty Array if cannot find aliases' do
      meth = Pry::Method(@class.new.method(:eruct))
      expect(meth.aliases).to be_empty
    end

    it 'should not include the own name in the list of aliases' do
      meth = Pry::Method(@class.new.method(:eat))
      expect(meth.aliases).not_to include "eat"
    end

    it 'should find aliases for top-level methods' do
      # top-level methods get added as private instance methods on Object
      class Object
        private
        def my_top_level_method ; end
        alias my_other_top_level_method my_top_level_method
      end

      meth = Pry::Method.new(method(:my_top_level_method))
      expect(meth.aliases).to include 'my_other_top_level_method'

      class Object
        remove_method :my_top_level_method
      end
    end

    it 'should be able to find aliases for methods implemented in C' do
      meth = Pry::Method(Hash.new.method(:key?))
      aliases = Set.new(meth.aliases)

      expect(aliases).to eq(Set.new(["include?", "member?", "has_key?"]))
    end
  end
end
