# frozen_string_literal: true

require 'stringio'

RSpec.describe Pry::Command do
  subject do
    Class.new(described_class) do
      def process; end
    end
  end

  let(:default_options) do
    {
      argument_required: false,
      interpolate: true,
      keep_retval: false,
      shellwords: true,
      takes_block: false,
      use_prefix: true,
      listing: 'nil'
    }
  end

  describe ".match" do
    context "when no argument is given" do
      context "and when match was defined previously" do
        before { subject.match('old-match') }

        it "doesn't overwrite match" do
          expect(subject.match).to eq('old-match')
        end
      end

      context "and when match was not defined previously" do
        it "sets match to nil" do
          subject.match
          expect(subject.match).to be_nil
        end
      end
    end

    context "when given an argument" do
      context "and when match is a string" do
        it "sets command options with listing as match" do
          subject.match('match') # rubocop:disable Performance/RedundantMatch
          expect(subject.command_options).to include(listing: 'match')
        end
      end

      context "and when match is an object" do
        let(:object) do
          obj = Object.new
          def obj.inspect
            'inspect'
          end
          obj
        end

        it "sets command options with listing as object's inspect" do
          subject.match(object)
          expect(subject.command_options).to include(listing: 'inspect')
        end
      end
    end
  end

  describe ".description" do
    context "and when description was defined previously" do
      before { subject.description('old description') }

      it "doesn't overwrite match" do
        subject.description
        expect(subject.description).to eq('old description')
      end
    end

    context "and when description was not defined previously" do
      it "sets description to nil" do
        expect(subject.description).to be_nil
      end
    end

    context "when given an argument" do
      it "sets description" do
        subject.description('description')
        expect(subject.description).to eq('description')
      end
    end
  end

  describe ".command_options" do
    context "when no argument is given" do
      context "and when command options were defined previously" do
        before { subject.command_options(foo: :bar) }

        it "returns memoized command options" do
          expect(subject.command_options).to eq(default_options.merge(foo: :bar))
        end
      end

      context "and when command options were not defined previously" do
        it "sets command options to default options" do
          subject.command_options
          expect(subject.command_options).to eq(default_options)
        end
      end
    end

    context "when given an argument" do
      let(:new_option) { { new_option: 'value' } }

      it "merges the argument with command options" do
        expect(subject.command_options(new_option))
          .to eq(default_options.merge(new_option))
      end
    end
  end

  describe ".banner" do
    context "when no argument is given" do
      context "and when banner was defined previously" do
        before { subject.banner('banner') }

        it "returns the memoized banner" do
          expect(subject.banner).to eq('banner')
        end
      end

      context "and when banner was not defined previously" do
        it "return nil" do
          subject.banner
          expect(subject.banner).to be_nil
        end
      end
    end

    context "when given an argument" do
      it "merges the argument with command options" do
        expect(subject.banner('banner')).to eq('banner')
      end
    end
  end

  describe ".block" do
    context "when block exists" do
      let(:block) { proc {} }

      it "returns the block" do
        subject.block = block
        expect(subject.block).to eql(block)
      end
    end

    context "when block doesn't exist" do
      it "uses #process method" do
        expect(subject.block.name).to eq(:process)
      end
    end
  end

  describe ".source" do
    it "returns source code of the method" do
      expect(subject.source).to eq("def process; end\n")
    end
  end

  describe ".doc" do
    subject do
      Class.new(described_class) do
        def help
          'help'
        end
      end
    end

    it "returns help output" do
      expect(subject.doc).to eq('help')
    end
  end

  describe ".source_file" do
    it "returns source file" do
      expect(subject.source_file).to match(__FILE__)
    end
  end

  describe ".source_line" do
    it "returns source line" do
      expect(subject.source_line).to be_kind_of(Integer)
    end
  end

  describe ".default_options" do
    context "when given a String argument" do
      it "returns default options with string listing" do
        expect(subject.default_options('listing'))
          .to eq(default_options.merge(listing: 'listing'))
      end
    end

    context "when given an Object argument" do
      let(:object) do
        obj = Object.new
        def obj.inspect
          'inspect'
        end
        obj
      end

      it "returns default options with object's inspect as listing" do
        expect(subject.default_options(object))
          .to eq(default_options.merge(listing: 'inspect'))
      end
    end
  end

  describe ".name" do
    it "returns the name of the command" do
      expect(subject.name).to eq('#<class(Pry::Command nil)>')
    end

    context "when super command name exists" do
      subject do
        parent = Class.new(described_class) do
          def name
            'parent name'
          end
        end

        Class.new(parent)
      end

      it "returns the name of the parent command" do
        expect(subject.name).to eq('#<class(Pry::Command nil)>')
      end
    end
  end

  describe ".inspect" do
    subject do
      Class.new(described_class) do
        def self.name
          'name'
        end
      end
    end

    it "returns command name" do
      expect(subject.inspect).to eq('name')
    end
  end

  describe ".command_name" do
    before { subject.match('foo') }

    it "returns listing" do
      expect(subject.command_name).to eq('foo')
    end
  end

  describe ".subclass" do
    it "returns a new class" do
      klass = subject.subclass('match', 'desc', {}, Module.new)
      expect(klass).to be_a(Class)
      expect(klass).not_to eql(subject)
    end

    it "includes helpers to the new class" do
      mod = Module.new { def foo; end }
      klass = subject.subclass('match', 'desc', {}, mod)
      expect(klass.new).to respond_to(:foo)
    end

    it "sets match on the new class" do
      klass = subject.subclass('match', 'desc', {}, Module.new)
      expect(klass.match).to eq('match')
    end

    it "sets description on the new class" do
      klass = subject.subclass('match', 'desc', {}, Module.new)
      expect(klass.description).to eq('desc')
    end

    it "sets command options on the new class" do
      klass = subject.subclass('match', 'desc', { foo: :bar }, Module.new)
      expect(klass.command_options).to include(foo: :bar)
    end

    it "sets block on the new class" do
      block = proc {}
      klass = subject.subclass('match', 'desc', { foo: :bar }, Module.new, &block)
      expect(klass.block).to eql(block)
    end
  end

  describe ".matches?" do
    context "when given value matches command regex" do
      before { subject.match('test-command') }

      it "returns true" do
        expect(subject.matches?('test-command')).to be_truthy
      end
    end

    context "when given value doesn't match command regex" do
      it "returns false" do
        expect(subject.matches?('test-command')).to be_falsey
      end
    end
  end

  describe ".match_score" do
    context "when command regex matches given value" do
      context "and when the size of last match is more than 1" do
        before { subject.match(/\.(.*)/) }

        it "returns the length of the first match" do
          expect(subject.match_score('.||')).to eq(1)
        end
      end

      context "and when the size of last match is 1 or 0" do
        before { subject.match('hi') }

        it "returns the length of the last match" do
          expect(subject.match_score('hi there')).to eq(2)
        end
      end
    end

    context "when command regex doesn't match given value" do
      it "returns -1" do
        expect(subject.match_score('test')).to eq(-1)
      end
    end
  end

  describe ".command_regex" do
    before { subject.match('test-command') }

    context "when use_prefix is true" do
      before { subject.command_options(use_prefix: true) }

      it "returns a Regexp without a prefix" do
        expect(subject.command_regex).to eq(/\Atest\-command(?!\S)/)
      end
    end

    context "when use_prefix is false" do
      before { subject.command_options(use_prefix: false) }

      it "returns a Regexp with a prefix" do
        expect(subject.command_regex).to eq(/\A(?:)?test\-command(?!\S)/)
      end
    end
  end

  describe ".convert_to_regex" do
    context "when given object is a String" do
      it "escapes the string as a Regexp" do
        expect(subject.convert_to_regex('foo.+')).to eq('foo\\.\\+')
      end
    end

    context "when given object is an Object" do
      let(:obj) { Object.new }

      it "returns the given object" do
        expect(subject.convert_to_regex(obj)).to eql(obj)
      end
    end
  end

  describe ".group" do
    context "when name is given" do
      it "sets group to that name" do
        expect(subject.group('Test Group')).to eq('Test Group')
      end
    end

    context "when source file matches a pry command" do
      before do
        expect_any_instance_of(Pry::Method).to receive(:source_file)
          .and_return('/pry/test_commands/test_command.rb')
      end

      it "sets group name to command name" do
        expect(subject.group).to eq('Test command')
      end
    end

    context "when source file matches a pry plugin" do
      before do
        expect_any_instance_of(Pry::Method).to receive(:source_file)
          .and_return('pry-test-1.2.3')
      end

      it "sets group name to plugin name" do
        expect(subject.group).to eq('pry-test (v1.2.3)')
      end
    end

    context "when source file matches 'pryrc'" do
      before do
        expect_any_instance_of(Pry::Method).to receive(:source_file)
          .and_return('pryrc')
      end

      it "sets group name to pryrc" do
        expect(subject.group).to eq('pryrc')
      end
    end

    context "when source file doesn't match anything" do
      it "returns '(other)'" do
        expect(subject.group).to eq('(other)')
      end
    end
  end

  describe ".state" do
    it "returns a command state" do
      expect(described_class.state).to be_an(OpenStruct)
    end
  end

  describe "#run" do
    let(:command_set) do
      set = Pry::CommandSet.new
      set.command('test') {}
      set
    end

    subject do
      command = Class.new(described_class)
      command.new(command_set: command_set, pry_instance: Pry.new)
    end

    it "runs a command from another command" do
      result = subject.run('test')
      expect(result).to be_command
    end
  end

  describe "#commands" do
    let(:command_set) do
      set = Pry::CommandSet.new
      set.command('test') do
        def process; end
      end
      set
    end

    subject do
      command = Class.new(described_class)
      command.new(command_set: command_set, pry_instance: Pry.new)
    end

    it "returns command set as a hash" do
      expect(subject.commands).to eq('test' => command_set['test'])
    end
  end

  describe "#void" do
    it "returns void value" do
      expect(subject.new.void).to eq(Pry::Command::VOID_VALUE)
    end
  end

  describe "#target_self" do
    let(:target) { binding }

    subject { Class.new(described_class).new(target: target) }

    it "returns the value of self inside the target binding" do
      expect(subject.target_self).to eq(target.eval('self'))
    end
  end

  describe "#state" do
    let(:target) { binding }

    subject { Class.new(described_class).new(pry_instance: Pry.new) }

    it "returns a state object" do
      expect(subject.state).to be_an(OpenStruct)
    end

    it "remembers the state" do
      subject.state.foo = :bar
      expect(subject.state.foo).to eq(:bar)
    end
  end

  describe "#interpolate_string" do
    context "when given string contains \#{" do
      let(:target) do
        foo = 'bar'
        binding
      end

      subject { Class.new(described_class).new(target: target) }

      it "returns the result of eval within target" do
        # rubocop:disable Lint/InterpolationCheck
        expect(subject.interpolate_string('#{foo}')).to eq('bar')
        # rubocop:enable Lint/InterpolationCheck
      end
    end

    context "when given string doesn't contain \#{" do
      it "returns the given string" do
        expect(subject.new.interpolate_string('foo')).to eq('foo')
      end
    end
  end

  describe "#check_for_command_collision" do
    let(:command_set) do
      set = Pry::CommandSet.new
      set.command('test') do
        def process; end
      end
      set
    end

    let(:output) { StringIO.new }

    subject do
      command = Class.new(described_class)
      command.new(command_set: command_set, target: target, output: output)
    end

    context "when a command collides with a local variable" do
      let(:target) do
        test = 'foo'
        binding
      end

      it "displays a warning" do
        subject.check_for_command_collision('test', '')
        expect(output.string)
          .to match("'test', which conflicts with a local-variable")
      end
    end

    context "when a command collides with a method" do
      let(:target) do
        def test; end
        binding
      end

      it "displays a warning" do
        subject.check_for_command_collision('test', '')
        expect(output.string).to match("'test', which conflicts with a method")
      end
    end

    context "when a command doesn't collide" do
      let(:target) do
        def test; end
        binding
      end

      it "doesn't display a warning" do
        subject.check_for_command_collision('nothing', '')
        expect(output.string).to be_empty
      end
    end
  end

  describe "#tokenize" do
    let(:target) { binding }
    let(:klass) { Class.new(described_class) }
    let(:target) { binding }

    subject { klass.new(target: target) }

    before { klass.match('test') }

    context "when given string uses interpolation" do
      let(:target) do
        foo = 4
        binding
      end

      before { klass.command_options(interpolate: true) }

      it "interpolates the string in the target's context" do
        # rubocop:disable Lint/InterpolationCheck
        expect(subject.tokenize('test #{1 + 2} #{3 + foo}'))
          .to eq(['test', '3 7', [], %w[3 7]])
        # rubocop:enable Lint/InterpolationCheck
      end

      context "and when interpolation is disabled" do
        before { klass.command_options(interpolate: false) }

        it "doesn't interpolate the string" do
          # rubocop:disable Lint/InterpolationCheck
          expect(subject.tokenize('test #{3 + foo}'))
            .to eq(['test', '#{3 + foo}', [], %w[#{3 + foo}]])
          # rubocop:enable Lint/InterpolationCheck
        end
      end
    end

    context "when given string doesn't match a command" do
      it "raises CommandError" do
        expect { subject.tokenize('boom') }
          .to raise_error(Pry::CommandError, /command which didn't match/)
      end
    end

    context "when target is not set" do
      subject { klass.new }

      it "still returns tokens" do
        expect(subject.tokenize('test --help'))
          .to eq(['test', '--help', [], ['--help']])
      end
    end

    context "when shellwords is enabled" do
      before { klass.command_options(shellwords: true) }

      it "strips quotes from the arguments" do
        expect(subject.tokenize(%(test "foo" 'bar' 1)))
          .to eq(['test', %("foo" 'bar' 1), [], %w[foo bar 1]])
      end
    end

    context "when shellwords is disabled" do
      before { klass.command_options(shellwords: false) }

      it "doesn't split quotes from the arguments" do
        # rubocop:disable Lint/PercentStringArray
        expect(subject.tokenize(%(test "foo" 'bar' 1)))
          .to eq(['test', %("foo" 'bar' 1), [], %w["foo" 'bar' 1]])
        # rubocop:enable Lint/PercentStringArray
      end
    end

    context "when command regex has captures" do
      before { klass.match(/perfectly (normal)( beast)/i) }

      it "returns the captures" do
        expect(subject.tokenize('Perfectly Normal Beast (honest!)')).to eq(
          [
            'Perfectly Normal Beast',
            '(honest!)',
            ['Normal', ' Beast'],
            ['(honest!)']
          ]
        )
      end
    end
  end

  describe "#process_line" do
    let(:klass) do
      Class.new(described_class) do
        def call(*args); end
      end
    end

    let(:target) do
      test = 4
      binding
    end

    let(:output) { StringIO.new }

    subject { klass.new(target: target, output: output) }

    before { klass.match(/test(y)?/) }

    it "sets arg_string" do
      subject.process_line('test -v')
      expect(subject.arg_string).to eq('-v')
    end

    it "sets captures" do
      subject.process_line('testy')
      expect(subject.captures).to eq(['y'])
    end

    describe "collision warnings" do
      context "when collision warnings are configured" do
        before do
          expect(Pry.config).to receive(:collision_warning).and_return(true)
        end

        it "prints a warning when there's a collision" do
          subject.process_line('test')
          expect(output.string).to match(/conflicts with a local-variable/)
        end
      end

      context "when collision warnings are not set" do
        before do
          expect(Pry.config).to receive(:collision_warning).and_return(false)
        end

        it "prints a warning when there's a collision" do
          subject.process_line('test')
          expect(output.string).to be_empty
        end
      end
    end
  end

  describe "#complete" do
    it "returns empty array" do
      expect(subject.new.complete('')).to eq([])
    end
  end
end
