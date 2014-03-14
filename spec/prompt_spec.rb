require_relative 'helper'

describe "Prompts" do
  describe "one-parameter prompt proc" do
    it 'should get full config object' do
      config = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => proc { |v| config = v })
      end
      config.is_a?(Pry::Config).should.be_true
    end

    it 'should get full config object, when using a proc array' do
      config1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => [proc { |v| config1 = v }, proc { |v| config2 = v }])
      end
      config1.is_a?(Pry::Config).should.be_true
    end

    it 'should receive correct data in the config object' do
      config = nil
      o = Object.new
      redirect_pry_io(InputTester.new("def hello", "exit-all")) do
        Pry.start(o, :prompt => proc { |v| config = v })
      end

      config.eval_string.should =~ /def hello/
      config.nesting_level.should == 0
      config.expr_number.should == 1
      config.cont.should.be_true
      config._pry_.is_a?(Pry).should.be_true
      config.object.should == o
    end
  end

  describe "BACKWARDS COMPATIBILITY: 3 parameter prompt proc" do
    it 'should get 3 parameters' do
      o = n = p = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, :prompt => proc { |obj, nesting, _pry_|
                    o, n, p = obj, nesting, _pry_ })
      end
      o.should == :test
      n.should == 0
      p.is_a?(Pry).should.be_true
    end

    it 'should get 3 parameters, when using proc array' do
      o1 = n1 = p1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, :prompt => [proc { |obj, nesting, _pry_|
                                       o1, n1, p1 = obj, nesting, _pry_ },
                                     proc { |obj, nesting, _pry_|
                                       o2, n2, p2 = obj, nesting, _pry_ }])
      end
      o1.should == :test
      n1.should == 0
      p1.is_a?(Pry).should.be_true
    end
  end
end
