require 'helper'

describe "raise-up" do
  before do
    @self  = "Pad.self = self"
    @inner = "Pad.inner = self"
    @outer = "Pad.outer = self"
  end

  after do
    Pad.clear
  end

  it "should raise the exception with raise-up" do
    redirect_pry_io(InputTester.new("raise NoMethodError", "raise-up NoMethodError")) do
      lambda { Pry.new.repl(0) }.should.raise NoMethodError
    end
  end

  it "should raise an unamed exception with raise-up" do
    redirect_pry_io(InputTester.new("raise 'stop'","raise-up 'noreally'")) do
      lambda { Pry.new.repl(0) }.should.raise RuntimeError, "noreally"
    end
  end

  it "should eat the exception at the last new pry instance on raise-up" do
    redirect_pry_io(InputTester.new(":inner.pry", "raise NoMethodError", @inner,
                                    "raise-up NoMethodError", @outer, "exit-all")) do
      Pry.start(:outer)
    end

    Pad.inner.should == :inner
    Pad.outer.should == :outer
  end

  it "should raise the most recently raised exception" do
    lambda { mock_pry("raise NameError, 'homographery'","raise-up") }.should.raise NameError, 'homographery'
  end

  it "should allow you to cd up and (eventually) out" do
    redirect_pry_io(InputTester.new("cd :inner", "raise NoMethodError", @inner,
                                    "deep = :deep", "cd deep","Pad.deep = self",
                                    "raise-up NoMethodError", "raise-up", @outer,
                                    "raise-up", "exit-all")) do
      lambda { Pry.start(:outer) }.should.raise NoMethodError
    end

    Pad.deep.should  == :deep
    Pad.inner.should == :inner
    Pad.outer.should == :outer
  end

  it "should jump immediately out of nested contexts with !" do
    lambda { mock_pry("cd 1", "cd 2", "cd 3", "raise-up! 'fancy that...'") }.should.raise RuntimeError, 'fancy that...'
  end
end
