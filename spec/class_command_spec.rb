# frozen_string_literal: true

RSpec.describe Pry::ClassCommand do
  describe ".inherited" do
    context "when match is defined" do
      subject do
        Class.new(described_class) do
          match('match')
        end
      end

      it "sets match on the subclass" do
        subclass = Class.new(subject)
        expect(subclass.match).to eq('match')
      end
    end

    context "when description is defined" do
      subject do
        Class.new(described_class) do
          description('description')
        end
      end

      it "sets description on the subclass" do
        subclass = Class.new(subject)
        expect(subclass.description).to eq('description')
      end
    end

    context "when command_options is defined" do
      subject do
        Class.new(described_class) do
          command_options(listing: 'listing')
        end
      end

      it "sets command_options on the subclass" do
        subclass = Class.new(subject)
        expect(subclass.command_options)
          .to match(hash_including(listing: 'listing'))
      end
    end
  end

  describe ".source" do
    subject { Class.new(described_class) }

    it "returns source code for the process method" do
      expect(subject.source).to match(/\Adef process\n.+\nend\n\z/)
    end
  end

  describe ".doc" do
    subject do
      Class.new(described_class) { banner('banner') }
    end

    it "returns source code for the process method" do
      expect(subject.doc).to eq("banner\n    -h, --help      Show this message.")
    end
  end

  describe ".source_location" do
    subject { Class.new(described_class) }

    it "returns source location" do
      expect(subject.source_location)
        .to match([/class_command.rb/, be_kind_of(Integer)])
    end
  end

  describe ".source_file" do
    subject { Class.new(described_class) }

    it "returns source file" do
      expect(subject.source_file).to match(/class_command.rb/)
    end
  end

  describe ".source_line" do
    subject { Class.new(described_class) }

    it "returns source file" do
      expect(subject.source_line).to be_kind_of(Integer)
    end
  end

  describe "#call" do
    subject do
      command = Class.new(described_class) do
        def process; end
      end
      command.new
    end

    before { subject.class.banner('banner') }

    it "invokes setup" do
      expect(subject).to receive(:setup)
      expect(subject.call)
    end

    it "sets command's opts" do
      expect { subject.call }.to change { subject.opts }
        .from(nil).to(an_instance_of(Pry::Slop))
    end

    it "sets command's args" do
      expect { subject.call('foo', 'bar') }.to change { subject.args }
        .from(nil).to(%w[foo bar])
    end

    context "when help is invoked" do
      let(:output) { StringIO.new }

      before { subject.output = output }

      it "outputs help info" do
        subject.call('--help')
        expect(subject.output.string)
          .to eq("banner\n    -h, --help      Show this message.\n")
      end

      it "returns void value" do
        expect(subject.call('--help')).to eql(Pry::Command::VOID_VALUE)
      end
    end

    context "when help is not invloved" do
      context "when #process accepts no arguments" do
        subject do
          command = Class.new(described_class) do
            def process; end
          end
          command.new
        end

        it "calls the command despite passed arguments" do
          expect { subject.call('foo') }.not_to raise_error
        end
      end

      context "when #process accepts some arguments" do
        subject do
          command = Class.new(described_class) do
            def process(arg, other); end
          end
          command.new
        end

        it "calls the command even if there's not enough arguments" do
          expect { subject.call('foo') }.not_to raise_error
        end

        it "calls the command even if there are more arguments than needed" do
          expect { subject.call('1', '2', '3') }.not_to raise_error
        end
      end

      context "when passed a variable-length array" do
        subject do
          command = Class.new(described_class) do
            def process(arg, other); end
          end
          command.new
        end

        it "calls the command without arguments" do
          expect { subject.call }.not_to raise_error
        end

        it "calls the command with some arguments" do
          expect { subject.call('1', '2', '3') }.not_to raise_error
        end
      end
    end
  end

  describe "#help" do
    subject { Class.new(described_class).new }

    before { subject.class.banner('banner') }

    it "returns help output" do
      expect(subject.help)
        .to eq("banner\n    -h, --help      Show this message.")
    end
  end

  describe "#slop" do
    subject { Class.new(described_class).new }

    before { subject.class.banner('    banner') }

    it "returns a Slop instance" do
      expect(subject.slop).to be_a(Pry::Slop)
    end

    it "makes Slop's banner unindented" do
      slop = subject.slop
      expect(slop.banner).to eq('banner')
    end

    it "defines the help option" do
      expect(subject.slop.fetch_option(:help)).not_to be_nil
    end

    context "when there are subcommands" do
      subject do
        command = Class.new(described_class) do
          def subcommands(cmd)
            cmd.command(:download)
          end
        end
        command.new
      end

      it "adds subcommands to Slop" do
        expect(subject.slop.fetch_command(:download)).not_to be_nil
      end
    end

    context "when there are options" do
      subject do
        command = Class.new(described_class) do
          def options(opt)
            opt.on(:test)
          end
        end
        command.new
      end

      it "adds subcommands to Slop" do
        expect(subject.slop.fetch_option(:test)).not_to be_nil
      end
    end
  end

  describe "#complete" do
    subject do
      command = Class.new(described_class) do
        def options(opt)
          opt.on(:d, :download)
          opt.on(:u, :upload)
          opt.on(:x)
        end
      end
      command.new
    end

    before { subject.class.banner('') }

    it "generates option completions" do
      expect(subject.complete(''))
        .to match(array_including('--download ', '--upload ', '-x'))
    end
  end

  describe "#process" do
    it "raises CommandError" do
      expect { subject.process }
        .to raise_error(Pry::CommandError, /not implemented/)
    end
  end
end
