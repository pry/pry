# frozen_string_literal: true

RSpec.describe Pry::CommandSet do
  let(:set) do
    Pry::CommandSet.new { import(Pry::Commands) }
  end

  describe "#new" do
    it "merges other set with itself" do
      other_set = described_class.new
      other_set.command('test') {}
      expect(described_class.new(other_set).count).to eq(1)
    end

    context "when block given" do
      it "instance evals the block" do
        other = described_class.new do
          command('test') {}
        end
        expect(described_class.new(other).count).to eq(1)
      end
    end
  end

  describe "#block_command" do
    it "defines a new command" do
      subject.block_command('test')
      expect(subject.count).to eq(1)
    end

    it "assings default description" do
      command = subject.block_command('test')
      expect(command.description).to eq('No description.')
    end

    it "can overwrite default description" do
      command = subject.block_command('test', 'test description')
      expect(command.description).to eq('test description')
    end

    it "configures command options" do
      command = subject.block_command(
        'test', 'test description', some_option: 'some value'
      )
      expect(command.options).to include(some_option: 'some value')
    end

    context "when description is a hash" do
      it "treats description as options" do
        command = subject.block_command('test', some_option: 'some value')
        expect(command.options).to include(some_option: 'some value')
      end
    end
  end

  describe "#create_command" do
    it "defines a new class command" do
      subject.create_command('test') {}
      expect(subject.count).to eq(1)
    end

    it "assings default description" do
      command = subject.create_command('test') {}
      expect(command.description).to eq('No description.')
    end

    it "can overwrite default description" do
      command = subject.create_command('test', 'test description') {}
      expect(command.description).to eq('test description')
    end

    it "configures command options" do
      command = subject.create_command(
        'test', 'test description', some_option: 'some value'
      ) {}
      expect(command.options).to include(some_option: 'some value')
    end

    it "class_evals the given block in the command context" do
      command = subject.create_command('test') do
        description('class eval description')
      end
      expect(command.description).to eq('class eval description')
    end

    context "when description is a hash" do
      it "treats description as options" do
        command = subject.create_command('test', some_option: 'some value') {}
        expect(command.options).to include(some_option: 'some value')
      end
    end
  end

  describe "#each" do
    it "iterates over commands" do
      subject.command('test')
      expect(subject.each.first.first).to eq('test')
    end
  end

  describe "#delete" do
    it "deletes given commands" do
      subject.command('peach')
      subject.command('kiwi')
      subject.command('apple')

      subject.delete('kiwi', 'apple')

      expect(subject.count).to eq(1)
    end
  end

  describe "#import" do
    let(:first_set) { described_class.new.tap { |set| set.command('first') } }
    let(:second_set) { described_class.new.tap { |set| set.command('second') } }

    it "imports commands from given sets" do
      subject.import(first_set, second_set)
      expect(subject.count).to eq(2)
    end

    it "returns self" do
      expect(subject.import(first_set)).to eql(subject)
    end

    it "includes given sets' helper modules" do
      subject.import(first_set, second_set)
      expect(subject.helper_module.ancestors.size).to eq(3)
    end
  end

  describe "#import_from" do
    let(:other_set) do
      set = described_class.new
      set.command('kiwi')
      set.command('peach')
      set.command('plum')
      set
    end

    it "imports matching command from a set" do
      subject.import_from(other_set, 'kiwi', 'peach')
      expect(subject.count).to eq(2)
    end

    it "returns self" do
      expect(subject.import_from(other_set)).to eql(subject)
    end

    it "includes other set's helper module" do
      subject.import_from(other_set)
      expect(subject.helper_module.ancestors.size).to eq(2)
    end
  end

  describe "#find_command_by_match_or_listing" do
    it "returns a matching by name command" do
      subject.command('test')
      command = subject.find_command_by_match_or_listing('test')
      expect(command.command_name).to eq('test')
    end

    it "returns a matching by listing command" do
      subject.command('test', listing: 'wtf')
      command = subject.find_command_by_match_or_listing('wtf')
      expect(command.command_name).to eq('wtf')
    end

    it "raises ArgumentError on non-matching command" do
      expect { subject.find_command_by_match_or_listing('test') }
        .to raise_error(ArgumentError, "cannot find a command: 'test'")
    end
  end

  describe "#alias_command" do
    before { subject.command('test') }

    it "returns the aliased command" do
      new_command = subject.alias_command('new-test', 'test')
      expect(new_command.command_name).to eq('new-test')
    end

    it "sets description for the aliased command automatically" do
      new_command = subject.alias_command('new-test', 'test')
      expect(new_command.description).to eq('Alias for `test`')
    end

    it "sets aliased command's listing for string alias" do
      new_command = subject.alias_command('new-test', 'test')
      expect(new_command.options).to include(listing: 'new-test')
    end

    it "sets aliased command's listing for regex alias" do
      new_command = subject.alias_command(/test[!?]+/, 'test')
      expect(new_command.options[:listing].to_s).to eq('/test[!?]+/')
    end

    it "sets group for the aliased command automatically" do
      new_command = subject.alias_command('new-test', 'test')
      expect(new_command.group).to eq('Aliases')
    end

    context "when string description is provided" do
      it "uses the given description for the aliased command" do
        new_command = subject.alias_command('new-test', 'test', desc: 'description')
        expect(new_command.description).to eq('description')
      end
    end

    context "when non-string description is provided" do
      it "uses the string representation of the given object" do
        new_command = subject.alias_command('new-test', 'test', desc: Object.new)
        expect(new_command.description).to match(/#<Object.+/)
      end
    end

    context "when command doesn't match" do
      it "raises RuntimeError" do
        expect { subject.alias_command('nonexisting-command', 'action') }
          .to raise_error(RuntimeError, "command: 'action' not found")
      end
    end
  end

  describe "#rename_command" do
    before { subject.command('test') }

    it "renames a comamnd" do
      subject.rename_command('new-name', 'test')
      expect(subject['test']).to be_nil
      expect(subject['new-name']).not_to be_nil
    end

    it "can optionally set custom description" do
      subject.rename_command('new-name', 'test', description: 'new description')
      expect(subject['new-name'].description).to eq('new description')
    end

    context "when provided command is not registered" do
      it "raises ArgumentError" do
        expect { subject.rename_command('new-name', 'unknown') }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe "#desc" do
    before { subject.command('test') }

    it "sets command description" do
      subject.desc('test', 'test description')
      expect(subject['test'].description).to eq('test description')
    end

    it "gets command description" do
      expect(subject.desc('test')).to eq('No description.')
    end
  end

  describe "#list_commands" do
    before do
      subject.command('test-one')
      subject.command('test-two')
    end

    it "returns the list of commands" do
      expect(subject.list_commands).to eq(%w[test-one test-two])
    end
  end

  describe "#to_hash" do
    before { subject.command('test') }

    it "converts commands to hash" do
      expect(subject.to_hash).to include('test' => respond_to(:command_name))
    end

    it "doesn't mutate original commands" do
      hash = subject.to_hash
      hash['foo'] = 'bar'
      expect(subject.to_hash).not_to include('foo')
    end
  end

  describe "#[]" do
    context "when there's an unambiguous command" do
      before { subject.command('test') }

      it "selects the command according to the given pattern" do
        expect(subject['test']).to respond_to(:command_name)
      end
    end

    context "when there's an ambiguous command" do
      before do
        subject.command(/\.(.*)/)
        subject.command(/\.*(.*)/)
      end

      it "prefers a command with a higher score" do
        expect(subject['.foo'].command_name).to eq("/\\.(.*)/")
        expect(subject['..foo'].command_name).to eq("/\\.*(.*)/")
      end
    end
  end

  describe "#[]=" do
    before { subject.command('test') }

    it "rebinds the command with key" do
      subject['test-1'] = subject['test']
      expect(subject['test-1'].match).to eq('test-1')
    end

    context "when given command is nil" do
      it "deletes the command matching the pattern" do
        subject['test'] = nil
        expect(subject.count).to be_zero
      end
    end

    context "when given command is not a subclass of Pry::Command" do
      it "raises TypeError" do
        expect { subject['test'] = 1 }
          .to raise_error(TypeError, 'command is not a subclass of Pry::Command')
      end
    end
  end

  describe "#add_command" do
    it "adds a command" do
      subject.add_command(Class.new(Pry::Command))
      expect(subject.count).to eq(1)
    end
  end

  describe "#find_command_for_help" do
    before { subject.command('test') }

    context "when the command can be found" do
      it "returns the command" do
        expect(subject.find_command_for_help('test')).to respond_to(:command_name)
      end
    end

    context "when the command cannot be found" do
      it "returns nil" do
        expect(subject.find_command_for_help('foo')).to be_nil
      end
    end
  end

  describe "#valid_command?" do
    before { subject.command('test') }

    context "when command can be found" do
      it "returns true" do
        expect(subject.valid_command?('test')).to be_truthy
      end
    end

    context "when command cannot be found" do
      it "returns false" do
        expect(subject.valid_command?('foo')).to be_falsey
      end
    end
  end

  describe "#process_line" do
    before { subject.command('test') {} }

    context "when the given line is a command" do
      it "returns a command" do
        expect(subject.process_line('test')).to be_command
      end

      it "returns a non-void command" do
        expect(subject.process_line('test')).to be_void_command
      end

      context "and context is provided" do
        before { subject.command('test') { output.puts('kiwi') } }

        it "passes the context to the command" do
          output = StringIO.new
          subject.process_line('test', output: output)
          expect(output.string).to eq("kiwi\n")
        end
      end
    end

    context "when the given line is not a command" do
      it "returns not a command" do
        expect(subject.process_line('abcdefg')).not_to be_command
      end

      it "returns a void result" do
        expect(subject.process_line('test')).to be_void_command
      end
    end
  end

  # TODO: rewrite this block.
  if defined?(Bond)
    describe "#complete" do
      it "should list all command names" do
        set.create_command('susan') {}
        expect(set.complete('sus')).to.include 'susan '
      end

      it "should delegate to commands" do
        set.create_command('susan') do
          def complete(_search)
            ['--foo']
          end
        end
        expect(set.complete('susan ')).to eq ['--foo']
      end
    end
  end
end
