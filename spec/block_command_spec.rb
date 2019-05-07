# frozen_string_literal: true

RSpec.describe Pry::BlockCommand do
  subject { Class.new(described_class).new }

  describe "#call" do
    context "when #process accepts no arguments" do
      let(:block) do
        def process; end
        method(:process)
      end

      before { subject.class.block = block }

      it "calls the block despite passed arguments" do
        expect { subject.call(1, 2) }.not_to raise_error
      end
    end

    context "when #process accepts some arguments" do
      let(:block) do
        def process(arg, other); end
        method(:process)
      end

      before { subject.class.block = block }

      it "calls the block even if there's not enough arguments" do
        expect { subject.call(1) }.not_to raise_error
      end

      it "calls the block even if there are more arguments than needed" do
        expect { subject.call(1, 2, 3) }.not_to raise_error
      end
    end

    context "when passed a variable-length array" do
      let(:block) do
        def process(*args); end
        method(:process)
      end

      before { subject.class.block = block }

      it "calls the block without arguments" do
        expect { subject.call }.not_to raise_error
      end

      it "calls the block with some arguments" do
        expect { subject.call(1, 2, 3) }.not_to raise_error
      end
    end
  end

  describe "#help" do
    before do
      subject.class.description = 'desc'
      subject.class.command_options(listing: 'listing')
    end

    it "returns help output" do
      expect(subject.help).to eq('listing            desc')
    end
  end
end
