# frozen_string_literal: true

RSpec.describe Pry::Env do
  describe "#[]" do
    let(:key) { 'PRYTESTKEY' }

    after { ENV.delete(key) }

    context "when ENV contains the passed key" do
      before { ENV[key] = 'val' }
      after { ENV.delete(key) }

      specify { expect(described_class[key]).to eq('val') }
    end

    context "when ENV doesn't contain the passed key" do
      specify { expect(described_class[key]).to be_nil }
    end

    context "when ENV contains the passed key but its value is nil" do
      before { ENV[key] = '' }

      specify { expect(described_class[key]).to be_nil }
    end
  end
end
