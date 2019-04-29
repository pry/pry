RSpec.describe Pry::ControlDHandler do
  context "when given eval string is non-empty" do
    let(:eval_string) { 'hello' }
    let(:pry_instance) { Pry.new }

    it "clears input buffer" do
      described_class.default(eval_string, pry_instance)
      expect(eval_string).to be_empty
    end
  end

  context "when given eval string is empty & pry instance has one binding" do
    let(:eval_string) { '' }
    let(:pry_instance) { Pry.new.tap { |p| p.binding_stack = [binding] } }

    it "throws :breakout" do
      expect { described_class.default(eval_string, pry_instance) }
        .to throw_symbol(:breakout)
    end

    it "clears binding stack" do
      expect { described_class.default(eval_string, pry_instance) }
        .to throw_symbol
      expect(pry_instance.binding_stack).to be_empty
    end
  end

  context "when given eval string is empty & pry instance has 2+ bindings" do
    let(:eval_string) { '' }
    let(:binding1) { binding }
    let(:binding2) { binding }
    let(:binding_stack) { [binding1, binding2] }

    let(:pry_instance) do
      Pry.new.tap { |p| p.binding_stack = binding_stack }
    end

    it "saves a dup of the current binding stack in the 'cd' command" do
      described_class.default(eval_string, pry_instance)
      cd_state = pry_instance.commands['cd'].state
      expect(cd_state.old_stack).to eq([binding1, binding2])
    end

    it "pops the binding off the stack" do
      described_class.default(eval_string, pry_instance)
      expect(pry_instance.binding_stack).to eq([binding1])
    end
  end
end
