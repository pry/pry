require_relative 'helper'

RSpec.describe Pry::Prompt do
  let(:prompt_value) do
    [proc{},proc{}]
  end

  let(:prompt_desc) do
    "$my custom prompt description$"
  end

  before do
    described_class.add_prompt "prompt-name", prompt_desc, prompt_value
  end

  after do
    described_class.remove_prompt "prompt-name"
  end

  describe ".add_prompt" do
    specify "adds new Prompt" do
      expect(described_class['prompt-name']).to be_instance_of(Pry::Prompt::PromptInfo)
    end

    specify "prompt appears in list-prompts" do
      expect(pry_eval("list-prompts")).to include("prompt-name")
      expect(pry_eval("list-prompts")).to include(prompt_desc)
    end

    specify "prompt is changed to via change-prompt" do
      expect(pry_eval("change-prompt prompt-name", "_pry_.prompt")).to eq(described_class['prompt-name'])
    end
  end

  describe ".remove_prompt" do
    specify "removes a prompt" do
      described_class.remove_prompt 'prompt-name'
      expect(described_class['prompt-name']).to eq(nil)
    end

    specify "prompt disappears from list-prompts" do
      described_class.remove_prompt 'prompt-name'
      expect(pry_eval("list-prompts")).to_not include("prompt-name")
    end
  end

  describe ".alias_prompt" do
    before do
      described_class.alias_prompt "prompt-name", "prompt-alias"
    end

    specify "creates alias" do
      expect(described_class.aliases_for("prompt-name")).to eq([described_class['prompt-alias']])
    end

    specify "alias appears in list-prompts" do
      expect(pry_eval("list-prompts")).to include("Aliases: prompt-alias")
    end

    specify "alias is changed to via change-prompt" do
      expect(pry_eval("change-prompt prompt-alias", "_pry_.prompt")).to eq(described_class['prompt-name'])
    end
  end
end

describe "Prompts" do
  describe "one-parameter prompt proc" do
    it 'should get full config object' do
      config = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => proc { |v| config = v })
      end
      expect(config.is_a?(Pry::Config)).to eq true
    end

    it 'should get full config object, when using a proc array' do
      config1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(self, :prompt => [proc { |v| config1 = v }, proc { |v| _config2 = v }])
      end
      expect(config1.is_a?(Pry::Config)).to eq true
    end

    it 'should receive correct data in the config object' do
      config = nil
      redirect_pry_io(InputTester.new("def hello", "exit-all")) do
        Pry.start(self, :prompt => proc { |v| config = v })
      end

      expect(config.eval_string).to match(/def hello/)
      expect(config.nesting_level).to eq 0
      expect(config.expr_number).to eq 1
      expect(config.cont).to eq true
      expect(config._pry_.is_a?(Pry)).to eq true
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
      expect(o).to eq :test
      expect(n).to eq 0
      expect(p.is_a?(Pry)).to eq true
    end

    it 'should get 3 parameters, when using proc array' do
      o1 = n1 = p1 = nil
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.start(:test, :prompt => [proc { |obj, nesting, _pry_|
                                       o1, n1, p1 = obj, nesting, _pry_ },
                                     proc { |obj, nesting, _pry_|
                                       _o2, _n2, _p2 = obj, nesting, _pry_ }])
      end
      expect(o1).to eq :test
      expect(n1).to eq 0
      expect(p1.is_a?(Pry)).to eq true
    end
  end
end
