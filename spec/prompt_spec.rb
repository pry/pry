require_relative 'helper'

describe "Prompts" do
  describe "one-parameter prompt proc" do
    it 'should get full config object' do
      config = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => proc { |v| config = v })
      end
      config.is_a?(Pry::Config).should eq true
    end

    it 'should get full config object, when using a proc array' do
      config1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => [proc { |v| config1 = v }, proc { |_v| _config2 = v }])
      end
      config1.is_a?(Pry::Config).should eq true
    end

    it 'should receive correct data in the config object' do
      config = nil
      redirect_pry_io(InputTester.new("def hello", "exit-all")) do
        Pry.start(self, :prompt => proc { |v| config = v })
      end

      config.eval_string.should =~ /def hello/
      config.nesting_level.should eq 0
      config.expr_number.should eq 1
      config.cont.should eq true
      config._pry_.is_a?(Pry).should eq true
      expect(config.object).to eq self
    end
  end

  describe "BACKWARDS COMPATIBILITY: 3 parameter prompt proc" do
    it 'should get 3 parameters' do
      o = n = p = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, :prompt => proc { |obj, nesting, _pry_|
                    o, n, p = obj, nesting, _pry_ })
      end
      o.should eq :test
      n.should eq 0
      p.is_a?(Pry).should eq true
    end

    it 'should get 3 parameters, when using proc array' do
      o1 = n1 = p1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, :prompt => [proc { |obj, nesting, _pry_|
                                       o1, n1, p1 = obj, nesting, _pry_ },
                                     proc { |obj, nesting, _pry_|
                                       _o2, _n2, _p2 = obj, nesting, _pry_ }])
      end
      o1.should eq :test
      n1.should eq 0
      p1.is_a?(Pry).should eq true
    end
  end
end
