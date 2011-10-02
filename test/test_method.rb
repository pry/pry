require 'helper'

describe Pry::Method do
  it "should use String names for compatibility" do
    klass = Class.new { def hello; end }
    Pry::Method.new(klass.instance_method(:hello)).name.should == "hello"
  end

  describe ".from_str" do
    it 'should look up instance methods if no methods available and no options provided' do
      klass = Class.new { def hello; end }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      meth.should == klass.instance_method(:hello)
    end

    it 'should look up methods if no instance methods available and no options provided' do
      klass = Class.new { def self.hello; end }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      meth.should == klass.method(:hello)
    end

    it 'should look up instance methods first even if methods available and no options provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass))
      meth.should == klass.instance_method(:hello)
    end

    it 'should look up instance methods if "instance-methods"  option provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass), {"instance-methods" => true})
      meth.should == klass.instance_method(:hello)
    end

    it 'should look up methods if :methods  option provided' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str(:hello, Pry.binding_for(klass), {:methods => true})
      meth.should == klass.method(:hello)
    end

    it 'should look up instance methods using the Class#method syntax' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str("klass#hello", Pry.binding_for(binding))
      meth.should == klass.instance_method(:hello)
    end

    it 'should look up methods using the object.method syntax' do
      klass = Class.new { def hello; end; def self.hello; end  }
      meth = Pry::Method.from_str("klass.hello", Pry.binding_for(binding))
      meth.should == klass.method(:hello)
    end

    it 'should NOT look up instance methods using the Class#method syntax if no instance methods defined' do
      klass = Class.new { def self.hello; end  }
      meth = Pry::Method.from_str("klass#hello", Pry.binding_for(binding))
      meth.should == nil
    end

    it 'should NOT look up methods using the object.method syntax if no methods defined' do
      klass = Class.new { def hello; end  }
      meth = Pry::Method.from_str("klass.hello", Pry.binding_for(binding))
      meth.should == nil
    end

    it 'should look up methods using klass.new.method syntax' do
      klass = Class.new { def hello; :hello; end }
      meth = Pry::Method.from_str("klass.new.hello", Pry.binding_for(binding))
      meth.name.should == "hello"
    end

    it 'should look up instance methods using klass.meth#method syntax' do
      klass = Class.new { def self.meth; Class.new; end }
      meth = Pry::Method.from_str("klass.meth#initialize", Pry.binding_for(binding))
      meth.name.should == "initialize"
    end
  end

  describe 'all_from_class' do
    def should_find_method(name)
      Pry::Method.all_from_class(@class).map(&:name).should.include(name)
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
      Pry::Method.all_from_class(@class).detect{ |x| x.name == 'meth' }.owner.should == @class
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
        Pry::Method.all_from_obj(@obj).map(&:name).should.include(name)
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
        Pry::Method.all_from_obj(@obj).map(&:name).should.not.include('meth')
      end
    end

    describe 'on classes' do
      def should_find_method(name)
        Pry::Method.all_from_obj(@class).map(&:name).should.include(name)
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
        Pry::Method.all_from_obj(@obj).map(&:name).should.not.include('meth')
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
        Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'meth' }.owner.should == (class << @class; self; end)
      end

      it "should attrbute overridden methods to the class not the module" do
        @class = Class.new { class << self; def meth; 1; end; end; extend Module.new{ def meth; 1; end; } }
        Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'meth' }.owner.should == (class << @class; self; end)
      end

      it "should attribute overridden methods to the relevant singleton class in preference to Class" do
        @class = Class.new { class << self; def allocate; 1; end; end }
        Pry::Method.all_from_obj(@class).detect{ |x| x.name == 'allocate' }.owner.should == (class << @class; self; end)
      end
    end
  end
end

