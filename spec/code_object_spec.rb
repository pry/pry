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

      @p = Pry.new
      @p.binding_stack = [binding]
    end

    after do
      Object.remove_const(:ClassyWassy)
    end

    it 'should lookup methods' do
      m = Pry::CodeObject.lookup("@obj.ziggy", @p)
      m.is_a?(Pry::Method).should == true
      m.name.to_sym.should == :ziggy
    end

    it 'should lookup modules' do
      m = Pry::CodeObject.lookup("ClassyWassy", @p)
      m.is_a?(Pry::WrappedModule).should == true
      m.source.should =~ /piggy/
    end

    it 'should lookup procs' do
      my_proc = proc { :hello }
      @p.binding_stack = [binding]
      m = Pry::CodeObject.lookup("my_proc", @p)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /hello/
    end

    describe 'commands lookup' do
      before do
        @p = Pry.new
        @p.binding_stack = [binding]
      end

      it 'should return command class' do
        @p.commands.command "jeremy-jones" do
          "lobster"
        end
        m = Pry::CodeObject.lookup("jeremy-jones", @p)
        (m <= Pry::Command).should == true
        m.source.should =~ /lobster/
      end

      describe "class commands" do
        before do
          class LobsterLady < Pry::ClassCommand
            match "lobster-lady"
            description "nada."
            def process
              "lobster"
            end
          end
        end

        after do
          Object.remove_const(:LobsterLady)
        end

        it 'should return Pry::ClassCommand class when looking up class command' do
          Pry.commands.add_command(LobsterLady)
          m = Pry::CodeObject.lookup("lobster-lady", @p)
          (m <= Pry::ClassCommand).should == true
          m.source.should =~ /class LobsterLady/
          Pry.commands.delete("lobster-lady")
        end

        it 'should return Pry::WrappedModule when looking up command class directly (as a class, not as a command)' do
          Pry.commands.add_command(LobsterLady)
          m = Pry::CodeObject.lookup("LobsterLady", @p)
          m.is_a?(Pry::WrappedModule).should == true
          m.source.should =~ /class LobsterLady/
          Pry.commands.delete("lobster-lady")
        end
      end

      it 'looks up commands by :listing name as well' do
        @p.commands.command /jeremy-.*/, "", :listing => "jeremy-baby" do
          "lobster"
        end
        m = Pry::CodeObject.lookup("jeremy-baby", @p)
        (m <= Pry::Command).should == true
        m.source.should =~ /lobster/
      end

      it 'finds nothing when passing nil as the first argument' do
        Pry::CodeObject.lookup(nil, @p).should == nil
      end

    end

    it 'should lookup instance methods defined on classes accessed via local variable' do
      o = Class.new do
        def princess_bubblegum
          "mathematic!"
        end
      end

      @p.binding_stack = [binding]
      m = Pry::CodeObject.lookup("o#princess_bubblegum", @p)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /mathematic!/
    end

    it 'should lookup class methods defined on classes accessed via local variable' do
      o = Class.new do
        def self.finn
          "4 realzies"
        end
      end
      @p.binding_stack = [binding]
      m = Pry::CodeObject.lookup("o.finn", @p)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /4 realzies/
    end

    it 'should lookup the class of an object (when given a variable)' do
      moddy = ClassyWassy.new
      @p.binding_stack = [binding]
      m = Pry::CodeObject.lookup("moddy", @p)
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
            @p.binding_stack = [@b1]
            m = Pry::CodeObject.lookup(v, @p)
            m.is_a?(Pry::WrappedModule).should == true
            m.name.should =~ /ClassyWassy/
          end
        end

        it 'should infer module object when binding self is an instance' do
          ["", nil].each do |v|
            @p.binding_stack = [@b2]
            m = Pry::CodeObject.lookup(v, @p)
            m.is_a?(Pry::WrappedModule).should == true
            m.name.should =~ /ClassyWassy/
          end
        end
      end

      describe "infer method objects" do
        it 'should infer method object from binding when inside method context' do
          b = ClassyWassy.new.piggy

          ["", nil].each do |v|
            @p.binding_stack = [b]
            m = Pry::CodeObject.lookup(v, @p)
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
      @p = Pry.new
      @p.binding_stack = [binding]
    end

    after do
      Object.remove_const(:MyClassyWassy)
      Object.remove_const(:CuteSubclass)
    end

    it 'should lookup original class with :super => 0' do
      m = Pry::CodeObject.lookup("CuteSubclass", @p, :super => 0)
      m.is_a?(Pry::WrappedModule).should == true
      m.wrapped.should == CuteSubclass
    end

    it 'should lookup immediate super class with :super => 1' do
      m = Pry::CodeObject.lookup("CuteSubclass", @p, :super => 1)
      m.is_a?(Pry::WrappedModule).should == true
      m.wrapped.should == MyClassyWassy
    end

    it 'should ignore :super parameter for commands' do
      p = Pry.new
      p.commands.command "jeremy-jones" do
        "lobster"
      end
      p.binding_stack = [binding]
      m = Pry::CodeObject.lookup("jeremy-jones", p, :super => 10)
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

      @p = Pry.new
      @p.binding_stack = [binding]
    end

    after do
      Object.remove_const(:ClassyWassy)
      Object.remove_method(:ClassyWassy)
    end

    it 'should look up methods before classes (at top-level)' do
      m = Pry::CodeObject.lookup("ClassyWassy", @p)
      m.is_a?(Pry::Method).should == true
      m.source.should =~ /ducky/
    end

    it 'should look up classes before methods when namespaced' do
      m = Pry::CodeObject.lookup("ClassyWassy::Puff", @p)
      m.is_a?(Pry::WrappedModule).should == true
      m.source.should =~ /tiggy/
    end

    it 'should look up locals before methods' do
      b = Pry.binding_for(ClassyWassy)
      b.eval("piggy = Puff.new")
      @p.binding_stack = [b]
      o = Pry::CodeObject.lookup("piggy", @p)
      o.is_a?(Pry::WrappedModule).should == true
    end

    # actually locals are never looked up (via co.default_lookup)  when they're classes, it
    # just falls through to co.method_or_class
    it 'should look up classes before locals' do
      c = ClassyWassy
      @p.binding_stack = [binding]
      o = Pry::CodeObject.lookup("c", @p)
      o.is_a?(Pry::WrappedModule).should == true
      o.wrapped.should == ClassyWassy
    end
  end
end
