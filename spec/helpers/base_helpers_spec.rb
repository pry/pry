# frozen_string_literal: true

RSpec.describe Pry::Helpers::BaseHelpers do
  describe ".use_ansi_codes?" do
    context "when not on windows", if: !Pry::Helpers::Platform.windows? do
      context "when TERM is not set" do
        before do
          allow(Pry::Env).to receive(:[]).and_call_original
          allow(Pry::Env).to receive(:[]).with('TERM').and_return(nil)
        end

        it "returns false" do
          expect(described_class.use_ansi_codes?).to be(false)
        end
      end

      context "when TERM is empty string" do
        before do
          allow(Pry::Env).to receive(:[]).and_call_original
          allow(Pry::Env).to receive(:[]).with('TERM').and_return(nil)
        end

        it "returns false" do
          expect(described_class.use_ansi_codes?).to be(false)
        end
      end

      context "when TERM is 'dumb'" do
        before do
          allow(Pry::Env).to receive(:[]).and_call_original
          allow(Pry::Env).to receive(:[]).with('TERM').and_return('dumb')
        end

        it "returns false" do
          expect(described_class.use_ansi_codes?).to be(false)
        end
      end

      context "when TERM is 'xterm'" do
        before do
          allow(Pry::Env).to receive(:[]).and_call_original
          allow(Pry::Env).to receive(:[]).with('TERM').and_return('xterm')
        end

        it "returns true" do
          expect(described_class.use_ansi_codes?).to be(true)
        end
      end

      context "when TERM is 'xterm-256color'" do
        before do
          allow(Pry::Env).to receive(:[]).and_call_original
          allow(Pry::Env).to receive(:[]).with('TERM').and_return('xterm-256color')
        end

        it "returns true" do
          expect(described_class.use_ansi_codes?).to be(true)
        end
      end
    end

    context "when on windows", if: Pry::Helpers::Platform.windows? do
      context "with ANSI support" do
        around do |example|
          old_term = ENV.fetch('TERM', nil)
          ENV.delete('TERM')
          example.run
          ENV['TERM'] = old_term
        end

        it "returns true even without TERM" do
          expect(described_class.use_ansi_codes?).to be(true)
        end
      end
    end
  end
end
