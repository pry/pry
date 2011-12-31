require 'helper'

describe Pry::WrappedModule do

  describe "#initialize" do
    it "should raise an exception when a non-module is passed" do
      lambda{ Pry::WrappedModule.new(nil) }.should.raise ArgumentError
    end
  end

  describe ".method_prefix" do
    before do
      Foo = Class.new
      @foo = Foo.new
    end

    after do
      Object.remove_const(:Foo)
    end

    it "should return Foo# for normal classes" do
      Pry::WrappedModule.new(Foo).method_prefix.should == "Foo#"
    end

    it "should return Bar# for modules" do
      Pry::WrappedModule.new(Kernel).method_prefix.should == "Kernel#"
    end

    it "should return Foo. for singleton classes of classes" do
      Pry::WrappedModule.new(class << Foo; self; end).method_prefix.should == "Foo."
    end

    describe "of singleton classes of objects" do
      Pry::WrappedModule.new(class << @foo; self; end).method_prefix.should == "self."
    end

    describe "of anonymous classes should not be empty" do
      Pry::WrappedModule.new(Class.new).method_prefix.should =~ /#<Class:.*>#/
    end

    describe "of singleton classes of anonymous classes should not be empty" do
      Pry::WrappedModule.new(class << Class.new; self; end).method_prefix.should =~ /#<Class:.*>./
    end
  end

  describe ".singleton_class?" do
    it "should be true for singleton classes" do
      Pry::WrappedModule.new(class << ""; self; end).singleton_class?.should == true
    end

    it "should be false for normal classes" do
      Pry::WrappedModule.new(Class.new).singleton_class?.should == false
    end

    it "should be false for modules" do
      Pry::WrappedModule.new(Module.new).singleton_class?.should == false
    end
  end

  describe ".singleton_instance" do
    it "should raise an exception when called on a non-singleton-class" do
      lambda{ Pry::WrappedModule.new(Class).singleton_instance }.should.raise ArgumentError
    end

    it "should return the attached object" do
      Pry::WrappedModule.new(class << "hi"; self; end).singleton_instance.should == "hi"
      Pry::WrappedModule.new(class << Object; self; end).singleton_instance.should.equal?(Object)
    end
  end
end

