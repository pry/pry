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
end

