# frozen_string_literal: true

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
      expect(described_class[:my_prompt]).to be_a(described_class)
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

  describe "#name" do
    it "returns name" do
      prompt = described_class.new(:test, '', Array.new(2) { proc { '' } })
      expect(prompt.name).to eq(:test)
    end
  end

  describe "#description" do
    it "returns description" do
      prompt = described_class.new(:test, 'descr', Array.new(2) { proc { '' } })
      expect(prompt.description).to eq('descr')
    end
  end

  describe "#prompt_procs" do
    it "returns the proc array" do
      prompt_procs = [proc { '>' }, proc { '*' }]
      prompt = described_class.new(:test, 'descr', prompt_procs)
      expect(prompt.prompt_procs).to eq(prompt_procs)
    end
  end

  describe "#wait_proc" do
    it "returns the first proc" do
      prompt_procs = [proc { '>' }, proc { '*' }]
      prompt = described_class.new(:test, '', prompt_procs)
      expect(prompt.wait_proc).to eq(prompt_procs.first)
    end
  end

  describe "#incomplete_proc" do
    it "returns the second proc" do
      prompt_procs = [proc { '>' }, proc { '*' }]
      prompt = described_class.new(:test, '', prompt_procs)
      expect(prompt.incomplete_proc).to eq(prompt_procs.last)
    end
  end

  describe "prompt invocation" do
    let(:pry) { Pry.new }

    let(:enum) do
      Enumerator.new do |y|
        range = ('a'..'z').to_enum
        loop { y << range.next }
      end
    end

    it "computes prompt name dynamically" do
      proc = described_class[:default].wait_proc
      pry.config.prompt_name = Pry::Config::LazyValue.new { enum.next }
      expect(proc.call(Object.new, 1, pry, '>')).to eq('[1] a(#<Object>):1> ')
      expect(proc.call(Object.new, 1, pry, '>')).to eq('[1] b(#<Object>):1> ')
    end
  end
end
