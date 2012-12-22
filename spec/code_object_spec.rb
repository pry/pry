require 'helper'

describe Pry::CodeObject do
  describe "basic lookups" do
    before do
      @obj = Object.new
      def @obj.ziggy
        "a flight of scarlet pigeons thunders round my thoughts"
      end

      class ClassyWassy
        def piggy
          binding
        end
      end
    end

    after do
      Object.remove_const(:ClassyWassy)
    end

    it 'should lookup methods' do
      m = Pry::CodeObject.lookup("@obj.ziggy", binding, Pry.new)
      m.is_a?(Pry::Method).should == true
      m.name.to_sym.should == :ziggy
    end

    it 'should lookup modules' do
      m = Pry::CodeObject.lookup("ClassyWassy", binding, Pry.new)
      m.is_a?(Pry::WrappedModule).should == true
      m.source.should =~ /piggy/
    end

    it 'should lookup procs' do
      my_proc = proc { :hello }
      m = Pry::CodeObject.lookup("my_proc", binding, Pry.new)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /hello/
    end

    it 'should lookup commands' do
      p = Pry.new
      p.commands.command "jeremy-jones" do
        "lobster"
      end
      m = Pry::CodeObject.lookup("jeremy-jones", binding, p)
      (m <= Pry::Command).should == true
      m.source.should =~ /lobster/
    end

    it 'should lookup commands by :listing name as well' do
      p = Pry.new
      p.commands.command /jeremy-.*/, "", :listing => "jeremy-baby" do
        "lobster"
      end
      m = Pry::CodeObject.lookup("jeremy-baby", binding, p)
      (m <= Pry::Command).should == true
      m.source.should =~ /lobster/
    end

    it 'should lookup instance methods defined on classes accessed via local variable' do
      o = Class.new do
        def princess_bubblegum
          "mathematic!"
        end
      end

      m = Pry::CodeObject.lookup("o#princess_bubblegum", binding, Pry.new)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /mathematic!/
    end

    it 'should lookup class methods defined on classes accessed via local variable' do
      o = Class.new do
        def self.finn
          "4 realzies"
        end
      end

      m = Pry::CodeObject.lookup("o.finn", binding, Pry.new)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /4 realzies/
    end

    it 'should lookup the class of an object (when given a variable)' do
      moddy = ClassyWassy.new
      m = Pry::CodeObject.lookup("moddy", binding, Pry.new)
      m.is_a?(Pry::WrappedModule).should == true
      m.source.should =~ /piggy/
    end

    describe "inferring object from binding when lookup str is empty/nil" do
      before do
        @b1 = Pry.binding_for(ClassyWassy)
        @b2 = Pry.binding_for(ClassyWassy.new)
      end

      describe "infer module objects" do
        it 'should infer module object when binding self is a module' do
          ["", nil].each do |v|
            m = Pry::CodeObject.lookup(v, @b1, Pry.new)
            m.is_a?(Pry::WrappedModule).should == true
            m.name.should =~ /ClassyWassy/
          end
        end

        it 'should infer module object when binding self is an instance' do
          ["", nil].each do |v|
            m = Pry::CodeObject.lookup(v, @b2, Pry.new)
            m.is_a?(Pry::WrappedModule).should == true
            m.name.should =~ /ClassyWassy/
          end
        end
      end

      describe "infer method objects" do
        it 'should infer method object from binding when inside method context' do
          b = ClassyWassy.new.piggy

          ["", nil].each do |v|
            m = Pry::CodeObject.lookup(v, b, Pry.new)
            m.is_a?(Pry::Method).should == true
            m.name.should =~ /piggy/
          end
        end
      end
    end
  end

  describe "lookups with :super" do
    before do
      class MyClassyWassy; end
      class CuteSubclass < MyClassyWassy; end
    end

    after do
      Object.remove_const(:MyClassyWassy)
      Object.remove_const(:CuteSubclass)
    end

    it 'should lookup original class with :super => 0' do
      m = Pry::CodeObject.lookup("CuteSubclass", binding, Pry.new, :super => 0)
      m.is_a?(Pry::WrappedModule).should == true
      m.wrapped.should == CuteSubclass
    end

    it 'should lookup immediate super class with :super => 1' do
      m = Pry::CodeObject.lookup("CuteSubclass", binding, Pry.new, :super => 1)
      m.is_a?(Pry::WrappedModule).should == true
      m.wrapped.should == MyClassyWassy
    end

    it 'should ignore :super parameter for commands' do
      p = Pry.new
      p.commands.command "jeremy-jones" do
        "lobster"
      end
      m = Pry::CodeObject.lookup("jeremy-jones", binding, p, :super => 10)
      m.source.should =~ /lobster/
    end
  end

  describe "precedence" do
    before do
      class ClassyWassy
        class Puff
          def tiggy
          end
        end

        def Puff
        end

        def piggy
        end
      end

      Object.class_eval do
        def ClassyWassy
          :ducky
        end
      end
    end

    after do
      Object.remove_const(:ClassyWassy)
      Object.remove_method(:ClassyWassy)
    end

    it 'should look up methods before classes (at top-level)' do
      m = Pry::CodeObject.lookup("ClassyWassy", binding, Pry.new)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /ducky/
    end

    it 'should look up classes before methods when namespaced' do
      m = Pry::CodeObject.lookup("ClassyWassy::Puff", binding, Pry.new)
      m.is_a?(Pry::WrappedModule).should == true
      m.source.should =~ /tiggy/
    end

    it 'should look up locals before methods' do
      b = Pry.binding_for(ClassyWassy)
      b.eval("piggy = Puff.new")
      o = Pry::CodeObject.lookup("piggy", b, Pry.new)
      o.is_a?(Pry::WrappedModule).should == true
    end

    # actually locals are never looked up (via co.other_object)  when they're classes, it
    # just falls through to co.method_or_class
    it 'should look up classes before locals' do
      c = ClassyWassy
      o = Pry::CodeObject.lookup("c", binding, Pry.new)
      o.is_a?(Pry::WrappedModule).should == true
      o.wrapped.should == ClassyWassy
    end
  end
end
