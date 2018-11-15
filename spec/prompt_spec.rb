require_relative 'helper'

describe Pry::Prompt do
  describe ".[]" do
    it "accesses prompts" do
      expect(described_class[:default]).not_to be_nil
    end
  end

  describe ".all" do
    it "returns a hash with prompts" do
      expect(described_class.all).to be_a(Hash)
    end

    it "returns a duplicate of original prompts" do
      described_class.all['foobar'] = Object.new
      expect(described_class['foobar']).to be_nil
    end
  end

  describe ".add" do
    after { described_class.instance_variable_get(:@prompts).delete('my_prompt') }

    it "adds a new prompt" do
      described_class.add(:my_prompt)
      expect(described_class[:my_prompt]).to be_a(Hash)
    end

    it "raises error when separators.size != 2" do
      expect { described_class.add(:my_prompt, '', [1, 2, 3]) }
        .to raise_error(ArgumentError, /separators size must be 2/)
    end

    it "raises error on adding a prompt with the same name" do
      described_class.add(:my_prompt)
      expect { described_class.add(:my_prompt) }
        .to raise_error(ArgumentError, /the 'my_prompt' prompt was already added/)
    end

    it "returns nil" do
      expect(described_class.add(:my_prompt)).to be_nil
    end
  end

  describe "one-parameter prompt proc" do
    it 'should get full config object' do
      config = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, prompt: proc { |v| config = v })
      end
      expect(config.is_a?(Pry::Config)).to eq true
    end

    it 'should get full config object, when using a proc array' do
      config1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, prompt: [proc { |v| config1 = v }, proc { |v| _config2 = v }])
      end
      expect(config1.is_a?(Pry::Config)).to eq true
    end

    it 'should receive correct data in the config object' do
      config = nil
      redirect_pry_io(InputTester.new("def hello", "exit-all")) do
        Pry.start(self, prompt: proc { |v| config = v })
      end

      expect(config.eval_string).to match(/def hello/)
      expect(config.nesting_level).to eq 0
      expect(config.expr_number).to eq 1
      expect(config.cont).to eq true
      expect(config._pry_.is_a?(Pry)).to eq true
      expect(config.object).to eq self
    end

    specify "object is Hash when current binding is a Hash" do
      config = nil
      h = {}
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(h, prompt: proc { |v| config = v })
      end
      expect(config.object).to be(h)
    end
  end

  describe "BACKWARDS COMPATIBILITY: 3 parameter prompt proc" do
    it 'should get 3 parameters' do
      o = n = p = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, prompt: proc { |obj, nesting, _pry_|
                    o, n, p = obj, nesting, _pry_ })
      end
      expect(o).to eq :test
      expect(n).to eq 0
      expect(p.is_a?(Pry)).to eq true
    end

    it 'should get 3 parameters, when using proc array' do
      o1 = n1 = p1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, prompt: [proc { |obj, nesting, _pry_|
                                       o1, n1, p1 = obj, nesting, _pry_ },
                                  proc { |obj, nesting, _pry_|
                                    _o2, _n2, _p2 = obj, nesting, _pry_ }])
      end
      expect(o1).to eq :test
      expect(n1).to eq 0
      expect(p1.is_a?(Pry)).to eq true
    end
  end

  it "can compute prompt name dynamically" do
    config = nil
    redirect_pry_io(InputTester.new("def hello", "exit-all")) do
      Pry.start(self, prompt: proc { |v| config = v })
    end

    enum = Enumerator.new do |y|
      count = 100
      loop { y << count += 1 }
    end
    config._pry_.config.prompt_name = Pry.lazy { enum.next }

    proc = described_class[:default][:value].first
    expect(proc.call(Object.new, 1, config._pry_)).to eq('[1] 101(#<Object>):1> ')
    expect(proc.call(Object.new, 1, config._pry_)).to eq('[1] 102(#<Object>):1> ')
  end
end
