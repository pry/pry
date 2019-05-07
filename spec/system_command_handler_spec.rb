# frozen_string_literal: true

require 'stringio'

RSpec.describe Pry::SystemCommandHandler do
  describe ".default" do
    let(:output) { StringIO.new }
    let(:pry_instance) { Pry.new }

    before { allow(Kernel).to receive(:system) }

    context "when command exists" do
      before do
        expect(Kernel).to receive(:system).with('test-command').and_return(true)
      end

      it "executes the command without printing the warning" do
        described_class.default(output, 'test-command', pry_instance)
        expect(output.string).to be_empty
      end
    end

    context "when doesn't exist" do
      before do
        allow(Kernel).to receive(:system).with('test-command').and_return(nil)
      end

      it "executes the command without printing the warning" do
        described_class.default(output, 'test-command', pry_instance)
        expect(output.string).to eq(
          "Error: there was a problem executing system command: test-command\n"
        )
      end
    end
  end
end
