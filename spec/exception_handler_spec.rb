# frozen_string_literal: true

RSpec.describe Pry::ExceptionHandler do
  describe ".handle_exception" do
    let(:output) { StringIO.new }
    let(:pry_instance) { Pry.new }

    context "when exception is a UserError and a SyntaxError" do
      let(:exception) do
        SyntaxError.new('cool syntax error, dude').extend(Pry::UserError)
      end

      it "prints the syntax error with customized message" do
        described_class.handle_exception(output, exception, pry_instance)
        expect(output.string).to start_with("SyntaxError: dude\n")
      end
    end

    context "when exception is a standard error" do
      let(:exception) do
        error = StandardError.new('oops')
        error.set_backtrace(["/bin/pry:23:in `<main>'"])
        error
      end

      it "prints standard error message" do
        described_class.handle_exception(output, exception, pry_instance)
        expect(output.string)
          .to eq("StandardError: oops\nfrom /bin/pry:23:in `<main>'\n")
      end
    end

    context "when exception is a nested standard error" do
      let(:exception) do
        error = nil
        begin
          begin
            raise 'nested oops'
          rescue # rubocop:disable Style/RescueStandardError
            raise 'outer oops'
          end
        rescue StandardError => outer_error
          error = outer_error
        end

        error
      end

      before do
        if RUBY_VERSION.start_with?('1.9', '2.0')
          skip("Ruby #{RUBY_VERSION} doesn't support nested exceptions")
        end
      end

      it "prints standard error message" do
        described_class.handle_exception(output, exception, pry_instance)
        expect(output.string).to match(
          /RuntimeError:\souter\soops\n
           from\s.+\n
           Caused\sby\sRuntimeError:\snested\soops\n
           from.+/x
        )
      end
    end
  end
end
