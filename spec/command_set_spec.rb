require_relative 'helper'

describe Pry::CommandSet do
  before do
    @set = Pry::CommandSet.new do
      import Pry::Commands
    end

    @ctx = {
      target: binding,
      command_set: @set,
      pry_instance: Pry.new(output: StringIO.new)
    }
  end

  describe "[]=" do
    it "removes a command from the command set" do
      expect(@set["help"]).not_to eq nil
      @set["help"] = nil
      expect(@set["help"]).to eq nil
      expect { @set.run_command(TOPLEVEL_BINDING, "help") }.to raise_error Pry::NoCommandError
    end

    it "replaces a command" do
      old_help = @set["help"]
      @set["help"] = @set["pry-version"]
      expect(@set["help"]).not_to eq old_help
    end

    it "rebinds the command with key" do
      @set["help-1"] = @set["help"]
      expect(@set["help-1"].match).to eq "help-1"
    end

    it "raises a TypeError when command is not a subclass of Pry::Command" do
      expect { @set["help"] = "hello" }.to raise_error TypeError
    end
  end

  it 'should call the block used for the command when it is called' do
    run = false
    @set.command 'foo' do
      run = true
    end

    @set.run_command @ctx, 'foo'
    expect(run).to eq true
  end

  it 'should pass arguments of the command to the block' do
    expect do |probe|
      @set.command('foo', &probe)
      @set.run_command(@ctx, 'foo', 1, 2, 3)
    end.to yield_with_args(1, 2, 3)
  end

  it 'should use the first argument as context' do
    inside = inner_scope do |probe|
      @set.command('foo', &probe)

      @set.run_command @ctx, 'foo'
    end

    expect(inside.context).to eq(@ctx)
  end

  it 'should raise an error when calling an undefined command' do
    @set.command('foo') {}
    expect { @set.run_command @ctx, 'bar' }.to raise_error Pry::NoCommandError
  end

  it 'should be able to remove its own commands' do
    @set.command('foo') {}
    @set.delete 'foo'

    expect { @set.run_command @ctx, 'foo' }.to raise_error Pry::NoCommandError
  end

  it 'should be able to remove its own commands, by listing name' do
    @set.command(/^foo1/, 'desc', listing: 'foo') {}
    @set.delete 'foo'

    expect { @set.run_command @ctx, /^foo1/ }.to raise_error Pry::NoCommandError
  end

  it 'should be able to import some commands from other sets' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, 'foo'
    expect(run).to eq true

    expect { @set.run_command @ctx, 'bar' }.to raise_error Pry::NoCommandError
  end

  it 'should return command set after import' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    expect(@set.import(other_set)).to eq @set
  end

  it 'should return command set after import_from' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    expect(@set.import_from(other_set, 'foo')).to eq @set
  end

  it 'should be able to import some commands from other sets using listing name' do
    run = false

    other_set = Pry::CommandSet.new do
      command(/^foo1/, 'desc', listing: 'foo') { run = true }
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, /^foo1/
    expect(run).to eq true
  end

  it 'should be able to import a whole set' do
    run = []

    other_set = Pry::CommandSet.new do
      command('foo') { run << true }
      command('bar') { run << true }
    end

    @set.import other_set

    @set.run_command @ctx, 'foo'
    @set.run_command @ctx, 'bar'
    expect(run).to eq [true, true]
  end

  it 'should be able to import sets at creation' do
    run = false
    @set.command('foo') { run = true }

    Pry::CommandSet.new(@set).run_command @ctx, 'foo'
    expect(run).to eq true
  end

  it 'should set the descriptions of commands' do
    @set.command('foo', 'some stuff') {}
    expect(@set['foo'].description).to eq 'some stuff'
  end

  describe "aliases" do
    it 'should be able to alias command' do
      run = false
      @set.command('foo', 'stuff') { run = true }

      @set.alias_command 'bar', 'foo'
      expect(@set['bar'].match).to eq 'bar'
      expect(@set['bar'].description).to eq 'Alias for `foo`'

      @set.run_command @ctx, 'bar'
      expect(run).to eq true
    end

    it "should be able to alias command with command_prefix" do
      run = false

      begin
        @set.command('owl', 'stuff') { run = true }
        @set.alias_command 'owlet', 'owl'

        Pry.config.command_prefix = '%'
        expect(@set['%owlet'].match).to eq 'owlet'
        expect(@set['%owlet'].description).to eq 'Alias for `owl`'

        @set.run_command @ctx, 'owlet'
        expect(run).to eq true
      ensure
        Pry.config.command_prefix = ''
      end
    end

    it 'should inherit options from original command' do
      run = false
      @set.command('foo', 'stuff', shellwords: true, interpolate: false) { run = true }

      @set.alias_command 'bar', 'foo'
      expect(@set['bar'].options[:shellwords]).to eq @set['foo'].options[:shellwords]
      expect(@set['bar'].options[:interpolate]).to eq @set['foo'].options[:interpolate]

      # however some options should not be inherited
      expect(@set['bar'].options[:listing]).not_to eq @set['foo'].options[:listing]
      expect(@set['bar'].options[:listing]).to eq "bar"
    end

    it 'should be able to specify alias\'s description when aliasing' do
      run = false
      @set.command('foo', 'stuff') { run = true }

      @set.alias_command 'bar', 'foo', desc: "tobina"
      expect(@set['bar'].match).to eq 'bar'
      expect(@set['bar'].description).to eq "tobina"

      @set.run_command @ctx, 'bar'
      expect(run).to eq true
    end

    it "should be able to alias a command by its invocation line" do
      run = false
      @set.command(/^foo1/, 'stuff', listing: 'foo') { run = true }

      @set.alias_command 'bar', 'foo1'
      expect(@set['bar'].match).to eq 'bar'
      expect(@set['bar'].description).to eq 'Alias for `foo1`'

      @set.run_command @ctx, 'bar'
      expect(run).to eq true
    end

    it "should be able to specify options when creating alias" do
      run = false
      @set.command(/^foo1/, 'stuff', listing: 'foo') { run = true }

      @set.alias_command(/^b.r/, 'foo1', listing: "bar")
      expect(@set.to_hash[/^b.r/].options[:listing]).to eq "bar"
    end

    it "should set description to default if description parameter is nil" do
      run = false
      @set.command(/^foo1/, 'stuff', listing: 'foo') { run = true }

      @set.alias_command "bar", 'foo1'
      expect(@set["bar"].description).to eq "Alias for `foo1`"
    end
  end

  it 'should be able to change the descriptions of commands' do
    @set.command('foo', 'bar') {}
    @set.desc 'foo', 'baz'

    expect(@set['foo'].description).to eq 'baz'
  end

  it 'should get the descriptions of commands' do
    @set.command('foo', 'bar') {}
    expect(@set.desc('foo')).to eq 'bar'
  end

  it 'should get the descriptions of commands, by listing' do
    @set.command(/^foo1/, 'bar', listing: 'foo') {}
    expect(@set.desc('foo')).to eq 'bar'
  end

  it 'should return Pry::Command::VOID_VALUE for commands by default' do
    @set.command('foo') { 3 }
    expect(@set.run_command(@ctx, 'foo')).to eq Pry::Command::VOID_VALUE
  end

  it 'should be able to keep return values' do
    @set.command('foo', '', keep_retval: true) { 3 }
    expect(@set.run_command(@ctx, 'foo')).to eq 3
  end

  it 'should be able to keep return values, even if return value is nil' do
    @set.command('foo', '', keep_retval: true) { nil }
    expect(@set.run_command(@ctx, 'foo')).to eq nil
  end

  it 'should be able to have its own helpers' do
    @set.command('foo') { my_helper }
    @set.helpers { def my_helper; end }

    @set.run_command(@ctx, 'foo')
    expect(Pry::Command.subclass('foo', '', {}, Module.new)
                .new({target: binding}))
                .not_to(respond_to :my_helper)
  end

  it 'should not recreate a new helper module when helpers is called' do
    @set.command('foo') do
      my_helper
      my_other_helper
    end

    @set.helpers do
      def my_helper; end
    end

    @set.helpers do
      def my_other_helper; end
    end

    @set.run_command(@ctx, 'foo')
  end

  it 'should import helpers from imported sets' do
    imported_set = Pry::CommandSet.new do
      helpers do
        def imported_helper_method; end
      end
    end

    @set.import imported_set
    @set.command('foo') { imported_helper_method }
    @set.run_command(@ctx, 'foo')
  end

  it 'should import helpers even if only some commands are imported' do
    imported_set = Pry::CommandSet.new do
      helpers do
        def imported_helper_method; end
      end

      command('bar') {}
    end

    @set.import_from imported_set, 'bar'
    @set.command('foo') { imported_helper_method }
    @set.run_command(@ctx, 'foo')
  end

  it 'should provide a :listing for a command that defaults to its name' do
    @set.command('foo', '') {}
    expect(@set['foo'].options[:listing]).to eq 'foo'
  end

  it 'should provide a :listing for a command that differs from its name' do
    @set.command('foo', '', listing: 'bar') {}
    expect(@set['foo'].options[:listing]).to eq 'bar'
  end

  it "should provide a 'help' command" do
    @ctx[:command_set] = @set
    @ctx[:output] = StringIO.new

    expect { @set.run_command(@ctx, 'help') }.to_not raise_error
  end

  describe "renaming a command" do
    it 'should be able to rename and run a command' do
      run = false
      @set.command('foo') { run = true }
      @set.rename_command('bar', 'foo')
      @set.run_command(@ctx, 'bar')
      expect(run).to eq true
    end

    it 'should accept listing name when renaming a command' do
      run = false
      @set.command('foo', "", listing: 'love') { run = true }
      @set.rename_command('bar', 'love')
      @set.run_command(@ctx, 'bar')
      expect(run).to eq true
    end

    it 'should raise exception trying to rename non-existent command' do
      expect { @set.rename_command('bar', 'foo') }.to raise_error ArgumentError
    end

    it 'should make old command name inaccessible' do
      @set.command('foo') {}
      @set.rename_command('bar', 'foo')
      expect { @set.run_command(@ctx, 'foo') }.to raise_error Pry::NoCommandError
    end

    it 'should be able to pass in options when renaming command' do
      desc    = "hello"
      listing = "bing"
      @set.command('foo') {}
      @set.rename_command('bar', 'foo', description: desc, listing: listing, keep_retval: true)
      expect(@set['bar'].description).to           eq desc
      expect(@set['bar'].options[:listing]).to     eq listing
      expect(@set['bar'].options[:keep_retval]).to eq true
    end
  end

  describe "before_* hook" do
    it 'should be called before the original command' do
      foo = []
      @set.command('foo') { foo << 1 }
      @set['foo'].hooks.add_hook('before_foo', 'name') { foo << 2 }
      @set.run_command(@ctx, 'foo')

      expect(foo).to eq [2, 1]
    end

    it 'should be called before the original command, using listing name' do
      foo = []
      @set.command(/^foo1/, '', listing: 'foo') { foo << 1 }
      cmd = @set.find_command_by_match_or_listing('foo')
      cmd.hooks.add_hook('before_foo', 'name') { foo << 2 }
      @set.run_command(@ctx, /^foo1/)

      expect(foo).to eq [2, 1]
    end

    it 'should share the context with the original command' do
      @ctx[:target] = "test target string".__binding__
      before_val  = nil
      orig_val    = nil
      @set.command('foo') { orig_val = target }
      @set['foo'].hooks.add_hook('before_foo', 'name') { before_val = target }
      @set.run_command(@ctx, 'foo')

      expect(before_val).to eq @ctx[:target]
      expect(orig_val).to eq @ctx[:target]
    end

    it 'should work when applied multiple times' do
      foo = []
      @set.command('foo') { foo << 1 }
      @set['foo'].hooks.add_hook('before_foo', 'name1') { foo << 2 }
      @set['foo'].hooks.add_hook('before_foo', 'name2') { foo << 3 }
      @set['foo'].hooks.add_hook('before_foo', 'name3') { foo << 4 }
      @set.run_command(@ctx, 'foo')

      expect(foo).to eq [2, 3, 4, 1]
    end
  end

  describe "after_* hooks" do
    it 'should be called after the original command' do
      foo = []
      @set.command('foo') { foo << 1 }
      @set['foo'].hooks.add_hook('after_foo', 'name') { foo << 2 }
      @set.run_command(@ctx, 'foo')

      expect(foo).to eq [1, 2]
    end

    it 'should be called after the original command, using listing name' do
      foo = []
      @set.command(/^foo1/, '', listing: 'foo') { foo << 1 }
      cmd = @set.find_command_by_match_or_listing('foo')
      cmd.hooks.add_hook('after_foo', 'name') { foo << 2 }
      @set.run_command(@ctx, /^foo1/)

      expect(foo).to eq [1, 2]
    end

    it 'should share the context with the original command' do
      @ctx[:target] = "test target string".__binding__
      after_val   = nil
      orig_val    = nil
      @set.command('foo') { orig_val = target }
      @set['foo'].hooks.add_hook('after_foo', 'name') { after_val = target }
      @set.run_command(@ctx, 'foo')

      expect(after_val).to eq @ctx[:target]
      expect(orig_val).to eq @ctx[:target]
    end

    it 'should determine the return value for the command' do
      @set.command('foo', 'bar', keep_retval: true) { 1 }
      @set['foo'].hooks.add_hook('after_foo', 'name') { 2 }
      expect(@set.run_command(@ctx, 'foo')).to eq 2
    end

    it 'should work when applied multiple times' do
      foo = []
      @set.command('foo') { foo << 1 }
      @set['foo'].hooks.add_hook('after_foo', 'name1') { foo << 2 }
      @set['foo'].hooks.add_hook('after_foo', 'name2') { foo << 3 }
      @set['foo'].hooks.add_hook('after_foo', 'name3') { foo << 4 }
      @set.run_command(@ctx, 'foo')

      expect(foo).to eq [1, 2, 3, 4]
    end
  end

  describe "before_command and after_command" do
    it 'should work when combining both before_command and after_command' do
      foo = []
      @set.command('foo') { foo << 1 }
      @set['foo'].hooks.add_hook('after_foo', 'name') { foo << 2 }
      @set['foo'].hooks.add_hook('before_foo', 'name') { foo << 3 }
      @set.run_command(@ctx, 'foo')

      expect(foo).to eq [3, 1, 2]
    end
  end

  describe 'find_command' do
    it 'should find commands with the right string' do
      cmd = @set.command('rincewind') {}
      expect(@set.find_command('rincewind')).to eq cmd
    end

    it 'should not find commands with spaces before' do
      @set.command('luggage') {}
      expect(@set.find_command(' luggage')).to eq nil
    end

    it 'should find commands with arguments after' do
      cmd = @set.command('vetinari') {}
      expect(@set.find_command('vetinari --knock 3')).to eq cmd
    end

    it 'should find commands with names containing spaces' do
      cmd = @set.command('nobby nobbs') {}
      expect(@set.find_command('nobby nobbs --steal petty-cash')).to eq cmd
    end

    it 'should find command defined by regex' do
      cmd = @set.command(/(capt|captain) vimes/i) {}
      expect(@set.find_command('Capt Vimes')).to eq cmd
    end

    it 'should find commands defined by regex with arguments' do
      cmd = @set.command(/(cpl|corporal) Carrot/i) {}
      expect(@set.find_command('cpl carrot --write-home')).to eq cmd
    end

    it 'should not find commands by listing' do
      @set.command(/werewol(f|ve)s?/, 'only once a month', listing: "angua") {}
      expect(@set.find_command('angua')).to eq nil
    end

    it 'should not find commands without command_prefix' do
      begin
        Pry.config.command_prefix = '%'
        @set.command('detritus') {}
        expect(@set.find_command('detritus')).to eq nil
      ensure
        Pry.config.command_prefix = ''
      end
    end

    it "should find commands that don't use the prefix" do
      begin
        Pry.config.command_prefix = '%'
        cmd = @set.command('colon', 'Sergeant Fred', use_prefix: false) {}
        expect(@set.find_command('colon')).to eq cmd
      ensure
        Pry.config.command_prefix = ''
      end
    end

    it "should find the command that has the longest match" do
      @set.command(/\.(.*)/) {}
      cmd2 = @set.command(/\.\|\|(.*)/) {}
      expect(@set.find_command('.||')).to eq cmd2
    end

    it "should find the command that has the longest name" do
      @set.command(/\.(.*)/) {}
      cmd2 = @set.command('.||') {}
      expect(@set.find_command('.||')).to eq cmd2
    end
  end

  describe '.valid_command?' do
    it 'should be true for commands that can be found' do
      @set.command('archchancellor')
      expect(@set.valid_command?('archchancellor of_the?(:University)')).to eq true
    end

    it 'should be false for commands that can\'' do
      expect(@set.valid_command?('def monkey(ape)')).to eq false
    end

    it 'should not cause argument interpolation' do
      @set.command('hello')
      expect { @set.valid_command?('hello #{raise "futz"}') }.to_not raise_error
    end
  end

  describe '.process_line' do
    it 'should return Result.new(false) if there is no matching command' do
     result = @set.process_line('1 + 42')
     expect(result.command?).to eq false
     expect(result.void_command?).to eq false
     expect(result.retval).to eq nil
    end

    it 'should return Result.new(true, VOID) if the command is not keep_retval' do
      @set.create_command('mrs-cake') do
        def process; 42; end
      end

      result = @set.process_line('mrs-cake')
      expect(result.command?).to eq true
      expect(result.void_command?).to eq true
      expect(result.retval).to eq Pry::Command::VOID_VALUE
    end

    it 'should return Result.new(true, retval) if the command is keep_retval' do
      @set.create_command('magrat', 'the maiden', keep_retval: true) do
        def process; 42; end
      end

      result = @set.process_line('magrat')
      expect(result.command?).to eq true
      expect(result.void_command?).to eq false
      expect(result.retval).to eq 42
    end

    it 'should pass through context' do
      ctx = {
        eval_string: "bloomers",
        pry_instance: Object.new,
        output: StringIO.new,
        target: binding
      }

      inside = inner_scope do |probe|
        @set.create_command('agnes') do
          define_method(:process, &probe)
        end

        @set.process_line('agnes', ctx)
      end

      expect(inside.eval_string).to eq(ctx[:eval_string])
      expect(inside.output).to eq(ctx[:output])
      expect(inside.target).to eq(ctx[:target])
      expect(inside._pry_).to eq(ctx[:pry_instance])
    end

    it 'should add command_set to context' do
      inside = inner_scope do |probe|
        @set.create_command(/nann+y ogg+/) do
          define_method(:process, &probe)
        end

        @set.process_line('nannnnnny oggggg')
      end

      expect(inside.command_set).to eq(@set)
    end
  end

  if defined?(Bond)
    describe '.complete' do
      it "should list all command names" do
        @set.create_command('susan') {}
        expect(@set.complete('sus')).to.include 'susan '
      end

      it "should delegate to commands" do
        @set.create_command('susan') { def complete(_search); ['--foo']; end }
        expect(@set.complete('susan ')).to eq ['--foo']
      end
    end
  end
end
