# frozen_string_literal: true

RSpec.describe Pry::ControlDHandler do
  context "when given eval string is non-empty" do
    let(:pry_instance) do
      Pry.new.tap do |p|
        p.eval_string = 'hello'
      end
    end

    it "clears input buffer" do
      described_class.default(pry_instance)
      expect(pry_instance.eval_string).to be_empty
    end
  end

  context "when given eval string is empty & pry instance has one binding" do
    let(:pry_instance) do
      Pry.new.tap do |p|
        p.eval_string = ''
        p.binding_stack = [binding]
      end
    end

    it "throws :breakout" do
      expect { described_class.default(pry_instance) }
        .to throw_symbol(:breakout)
    end

    it "clears binding stack" do
      expect { described_class.default(pry_instance) }
        .to throw_symbol
      expect(pry_instance.binding_stack).to be_empty
    end
  end

  context "when given eval string is empty & pry instance has 2+ bindings" do
    let(:binding1) { binding }
    let(:binding2) { binding }
    let(:binding_stack) { [binding1, binding2] }

    let(:pry_instance) do
      Pry.new.tap do |p|
        p.eval_string = ''
        p.binding_stack = binding_stack
      end
    end

    it "saves a dup of the current binding stack in the 'cd' command" do
      described_class.default(pry_instance)
      cd_state = pry_instance.commands['cd'].state
      expect(cd_state.old_stack).to eq([binding1, binding2])
    end

    it "pops the binding off the stack" do
      described_class.default(pry_instance)
      expect(pry_instance.binding_stack).to eq([binding1])
    end
  end
end
