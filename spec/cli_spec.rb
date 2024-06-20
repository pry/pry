# frozen_string_literal: true

RSpec.describe Pry::CLI do
  before { described_class.reset }

  describe ".add_options" do
    it "returns self" do
      expect(described_class.add_options).to eq(described_class)
    end

    context "when options is nil and a block is provided" do
      before { described_class.options = nil }

      it "sets the block as options" do
        block = proc {}
        described_class.add_options(&block)
        expect(described_class.options).to eql(block)
      end
    end

    context "when options were previously set" do
      it "overwrites the options proc that executes the provided block" do
        described_class.options = proc {}

        executed = false
        described_class.add_options { executed = true }

        described_class.options.call
        expect(executed).to be_truthy
      end

      it "overwrites the options proc that executes original options" do
        original_executed = false
        described_class.options = proc { original_executed = true }

        described_class.add_options {}
        described_class.options.call

        expect(original_executed).to be_truthy
      end
    end
  end

  describe ".add_plugin_options" do
    it "returns self" do
      expect(described_class.add_plugin_options).to eq(described_class)
    end

    it "loads cli options of plugins" do
      plugin_mock = double
      expect(plugin_mock).to receive(:load_cli_options)
      plugins = { 'pry-testplugin' => plugin_mock }
      expect(Pry).to receive(:plugins).and_return(plugins)

      described_class.add_plugin_options
    end
  end

  describe ".add_option_processor" do
    it "returns self" do
      expect(described_class.add_option_processor {}).to eq(described_class)
    end

    it "adds an option processor" do
      option_processor = proc {}
      described_class.add_option_processor(&option_processor)
      expect(described_class.option_processors).to eql([option_processor])
    end
  end

  describe ".parse_options" do
    context "when option exists" do
      before { described_class.options = proc { on(:v, 'test') } }

      it "removes the existing option from ARGV" do
        argv = %w[filename -v]
        described_class.parse_options(argv)
        expect(argv).not_to include('-v')
      end

      it "initializes session setup" do
        expect(Pry).to receive(:initial_session_setup)
        described_class.parse_options(%w[-v])
      end

      it "finalizes session setup" do
        expect(Pry).to receive(:final_session_setup)
        described_class.parse_options(%w[-v])
      end
    end

    context "when multiple options exist" do
      it "processes only called options" do
        processor_a_called = false
        processor_b_called = false
        processor_c_called = false
        described_class.options = proc do
          on('option-a', 'test a') { processor_a_called = true }
          on('option-b', 'test b') { processor_b_called = true }
          on('option-c', 'test c') { processor_c_called = true }
        end

        described_class.parse_options(%w[--option-a --option-b])

        expect(processor_a_called).to be_truthy
        expect(processor_b_called).to be_truthy
        expect(processor_c_called).to be_falsey
      end
    end

    context "when option doesn't exist" do
      it "raises error" do
        expect { described_class.parse_options(['--nothing']) }
          .to raise_error(Pry::CLI::NoOptionsError)
      end
    end

    context "when argv is passed with a dash (-)" do
      before { described_class.options = proc {} }

      it "sets everything after the dash as input args" do
        argv = %w[filename - foo bar]
        described_class.parse_options(argv)
        expect(described_class.input_args).to eq(%w[foo bar])
      end
    end

    context "when argv is passed with a double dash (--)" do
      before { described_class.options = proc {} }

      it "sets everything after the double dash as input args" do
        argv = %w[filename -- foo bar]
        described_class.parse_options(argv)
        expect(described_class.input_args).to eq(%w[foo bar])
      end
    end

    context "when invalid option is provided" do
      before { described_class.options = proc { on(:valid, 'valid') } }

      it "exits program" do
        expect(Kernel).to receive(:exit)
        expect(STDOUT).to receive(:puts)

        described_class.parse_options(%w[--invalid])
      end
    end
  end

  describe ".start" do
    before do
      # Don't start Pry session in the middle of tests.
      allow(Pry).to receive(:start)

      described_class.options = proc {}
    end

    it "sets Pry.cli to true" do
      opts = described_class.parse_options(%w[])
      described_class.start(opts)
      expect(Pry.cli).to be_truthy
    end

    context "when the help option is provided" do
      before { described_class.options = proc { on(:help, 'help') } }

      it "exits" do
        expect(Kernel).to receive(:exit)

        opts = described_class.parse_options(%w[--help])
        described_class.start(opts)
      end
    end

    context "when the context option is provided" do
      before { described_class.options = proc { on(:context=, 'context') } }

      it "initializes session setup" do
        expect(Pry).to receive(:initial_session_setup).twice
        opts = described_class.parse_options(%w[--context=Object])
        described_class.start(opts)
      end

      it "finalizes session setup" do
        expect(Pry).to receive(:final_session_setup).twice
        opts = described_class.parse_options(%w[--context=Object])
        described_class.start(opts)
      end

      it "starts Pry in the provided context" do
        expect(Pry).to receive(:start).with(
          instance_of(Binding), input: instance_of(StringIO)
        ) do |binding, _opts|
          expect(binding.eval('self')).to be_an(Object)
        end
        opts = described_class.parse_options(%w[--context=Object])
        described_class.start(opts)
      end
    end

    context "when the context option is not provided" do
      before { described_class.options = proc {} }

      it "starts Pry in the top level" do
        expect(Pry).to receive(:start).with(
          instance_of(Binding), input: instance_of(StringIO)
        ) do |binding, _opts|
          expect(binding.eval('self')).to eq(Pry.main)
        end
        opts = described_class.parse_options(%w[])
        described_class.start(opts)
      end
    end

    context "when there are some input args" do
      before { described_class.options = proc {} }

      it "loads files through repl and exits" do
        expect(Pry).to receive(:load_file_through_repl).with(match(%r{pry/foo}))
        expect(Kernel).to receive(:exit)

        opts = described_class.parse_options(%w[foo])
        described_class.start(opts)
      end
    end

    context "when 'pry' is passed as an input arg" do
      before { described_class.options = proc {} }

      it "does not load files through repl" do
        expect(Pry).not_to receive(:load_file_through_repl)

        opts = described_class.parse_options(%w[pry])
        described_class.start(opts)
      end
    end
  end
end
