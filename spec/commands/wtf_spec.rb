# frozen_string_literal: true

RSpec.describe Pry::Command::Wtf do
  describe "#process" do
    let(:output) { StringIO.new }

    let(:exception) do
      error = RuntimeError.new('oops')
      error.set_backtrace(Array.new(6) { "/bin/pry:23:in `<main>'" })
      error
    end

    let(:pry_instance) do
      instance = Pry.new
      instance.last_exception = exception
      instance
    end

    before do
      subject.pry_instance = pry_instance
      subject.output = output
      subject.opts = Pry::Slop.new
      subject.captures = ['']
    end

    context "when there wasn't an exception raised" do
      before { subject.pry_instance = Pry.new }

      it "raises Pry::CommandError" do
        expect { subject.process }
          .to raise_error(Pry::CommandError, 'No most-recent exception')
      end
    end

    context "when the verbose flag is missing" do
      before { expect(subject.opts).to receive(:verbose?).and_return(false) }

      it "prints only a part of the exception backtrace" do
        subject.process
        expect(subject.output.string).to eq(
          "\e[1mException:\e[0m RuntimeError: oops\n" \
          "--\n" \
          "0: /bin/pry:23:in `<main>'\n" \
          "1: /bin/pry:23:in `<main>'\n" \
          "2: /bin/pry:23:in `<main>'\n" \
          "3: /bin/pry:23:in `<main>'\n" \
          "4: /bin/pry:23:in `<main>'\n"
        )
      end
    end

    context "when the verbose flag is present" do
      before { expect(subject.opts).to receive(:verbose?).and_return(true) }

      it "prints full exception backtrace" do
        subject.process
        expect(subject.output.string).to eq(
          "\e[1mException:\e[0m RuntimeError: oops\n" \
          "--\n" \
          "0: /bin/pry:23:in `<main>'\n" \
          "1: /bin/pry:23:in `<main>'\n" \
          "2: /bin/pry:23:in `<main>'\n" \
          "3: /bin/pry:23:in `<main>'\n" \
          "4: /bin/pry:23:in `<main>'\n" \
          "5: /bin/pry:23:in `<main>'\n"
        )
      end
    end

    context "when captures contains exclamations (wtf?! invocation)" do
      before { subject.captures = ['!'] }

      it "prints more of backtrace" do
        subject.process
        expect(subject.output.string).to eq(
          "\e[1mException:\e[0m RuntimeError: oops\n" \
          "--\n" \
          "0: /bin/pry:23:in `<main>'\n" \
          "1: /bin/pry:23:in `<main>'\n" \
          "2: /bin/pry:23:in `<main>'\n" \
          "3: /bin/pry:23:in `<main>'\n" \
          "4: /bin/pry:23:in `<main>'\n" \
          "5: /bin/pry:23:in `<main>'\n" \
        )
      end
    end

    context "when given a nested exception" do
      let(:nested_exception) do
        begin
          begin
            begin
              raise 'inner'
            rescue RuntimeError
              raise 'outer'
            end
          end
        rescue RuntimeError => error
          error.set_backtrace(Array.new(6) { "/bin/pry:23:in `<main>'" })
          error.cause.set_backtrace(Array.new(6) { "/bin/pry:23:in `<main>'" })
          error
        end
      end

      before do
        if Gem::Version.new(RUBY_VERSION) <= Gem::Version.new('2.0.0')
          skip('Exception#cause is not supported')
        end

        pry_instance.last_exception = nested_exception
      end

      context "and when the verbose flag is missing" do
        before { expect(subject.opts).to receive(:verbose?).twice.and_return(false) }

        it "prints parts of both original and nested exception backtrace" do
          subject.process
          expect(subject.output.string).to eq(
            "\e[1mException:\e[0m RuntimeError: outer\n" \
            "--\n" \
            "0: /bin/pry:23:in `<main>'\n" \
            "1: /bin/pry:23:in `<main>'\n" \
            "2: /bin/pry:23:in `<main>'\n" \
            "3: /bin/pry:23:in `<main>'\n" \
            "4: /bin/pry:23:in `<main>'\n" \
            "\e[1mCaused by:\e[0m RuntimeError: inner\n" \
            "--\n" \
            "0: /bin/pry:23:in `<main>'\n" \
            "1: /bin/pry:23:in `<main>'\n" \
            "2: /bin/pry:23:in `<main>'\n" \
            "3: /bin/pry:23:in `<main>'\n" \
            "4: /bin/pry:23:in `<main>'\n"
          )
        end
      end

      context "and when the verbose flag present" do
        before { expect(subject.opts).to receive(:verbose?).twice.and_return(true) }

        it "prints both original and nested exception backtrace" do
          subject.process
          expect(subject.output.string).to eq(
            "\e[1mException:\e[0m RuntimeError: outer\n" \
            "--\n" \
            "0: /bin/pry:23:in `<main>'\n" \
            "1: /bin/pry:23:in `<main>'\n" \
            "2: /bin/pry:23:in `<main>'\n" \
            "3: /bin/pry:23:in `<main>'\n" \
            "4: /bin/pry:23:in `<main>'\n" \
            "5: /bin/pry:23:in `<main>'\n" \
            "\e[1mCaused by:\e[0m RuntimeError: inner\n" \
            "--\n" \
            "0: /bin/pry:23:in `<main>'\n" \
            "1: /bin/pry:23:in `<main>'\n" \
            "2: /bin/pry:23:in `<main>'\n" \
            "3: /bin/pry:23:in `<main>'\n" \
            "4: /bin/pry:23:in `<main>'\n" \
            "5: /bin/pry:23:in `<main>'\n"
          )
        end
      end
    end

    context "when the code flag is present" do
      let(:exception) do
        error = RuntimeError.new('oops')
        error.set_backtrace(
          Array.new(6) { "#{__FILE__}:#{__LINE__}:in `<main>'" }
        )
        error
      end

      before do
        expect(subject.opts).to receive(:code?).at_least(:once).and_return(true)
      end

      it "prints lines of code that exception frame references" do
        subject.process
        expect(subject.output.string).to eq(
          "\e[1mException:\e[0m RuntimeError: oops\n" \
          "--\n" \
          "0: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
          "             Array.new(6) { \"\#{__FILE__}:\#{__LINE__}:in `<main>'\" }\n" \
          "1: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
          "             Array.new(6) { \"\#{__FILE__}:\#{__LINE__}:in `<main>'\" }\n" \
          "2: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
          "             Array.new(6) { \"\#{__FILE__}:\#{__LINE__}:in `<main>'\" }\n" \
          "3: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
          "             Array.new(6) { \"\#{__FILE__}:\#{__LINE__}:in `<main>'\" }\n" \
          "4: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
          "             Array.new(6) { \"\#{__FILE__}:\#{__LINE__}:in `<main>'\" }\n"
        )
      end

      context "and when referenced frame doesn't exist" do
        before do
          expect(File).to receive(:open).at_least(:once).and_raise(Errno::ENOENT)
        end

        it "skips code and prints only the backtrace frame" do
          subject.process
          expect(subject.output.string).to eq(
            "\e[1mException:\e[0m RuntimeError: oops\n" \
            "--\n" \
            "0: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
            "1: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
            "2: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
            "3: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n" \
            "4: \e[1m#{__FILE__}:168:in `<main>'\e[0m\n"
          )
        end
      end
    end
  end
end
