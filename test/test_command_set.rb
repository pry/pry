require 'helper'

describe Pry::CommandSet do
  before do
    @set = Pry::CommandSet.new do
      import Pry::Commands
    end

    @ctx = {
      :target => binding,
      :command_set => @set
    }
  end

  it 'should call the block used for the command when it is called' do
    run = false
    @set.command 'foo' do
      run = true
    end

    @set.run_command @ctx, 'foo'
    run.should == true
  end

  it 'should pass arguments of the command to the block' do
    @set.command 'foo' do |*args|
      args.should == [1, 2, 3]
    end

    @set.run_command @ctx, 'foo', 1, 2, 3
  end

  it 'should use the first argument as context' do
    ctx = @ctx

    @set.command 'foo' do
      self.context.should == ctx
    end

    @set.run_command @ctx, 'foo'
  end

  it 'should raise an error when calling an undefined command' do
    @set.command('foo') {}
    lambda {
      @set.run_command @ctx, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to remove its own commands' do
    @set.command('foo') {}
    @set.delete 'foo'

    lambda {
      @set.run_command @ctx, 'foo'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to remove its own commands, by listing name' do
    @set.command(/^foo1/, 'desc', :listing => 'foo') {}
    @set.delete 'foo'

    lambda {
      @set.run_command @ctx, /^foo1/
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to import some commands from other sets' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, 'foo'
    run.should == true

    lambda {
      @set.run_command @ctx, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should return command set after import' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import(other_set).should == @set
  end

  it 'should return command set after import_from' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import_from(other_set, 'foo').should == @set
  end

  it 'should be able to import some commands from other sets using listing name' do
    run = false

    other_set = Pry::CommandSet.new do
      command(/^foo1/, 'desc', :listing => 'foo') { run = true }
    end

    @set.import_from(other_set, 'foo')

    @set.run_command @ctx, /^foo1/
    run.should == true
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
    run.should == [true, true]
  end

  it 'should be able to import sets at creation' do
    run = false
    @set.command('foo') { run = true }

    Pry::CommandSet.new(@set).run_command @ctx, 'foo'
    run.should == true
  end

  it 'should set the descriptions of commands' do
    @set.command('foo', 'some stuff') {}
    @set.commands['foo'].description.should == 'some stuff'
  end

  describe "aliases" do
    it 'should be able to alias command' do
      run = false
      @set.command('foo', 'stuff') { run = true }

      @set.alias_command 'bar', 'foo'
      @set.commands['bar'].match.should == 'bar'
      @set.commands['bar'].description.should == 'Alias for `foo`'

      @set.run_command @ctx, 'bar'
      run.should == true
    end

    it 'should inherit options from original command' do
      run = false
      @set.command('foo', 'stuff', :shellwords => true, :interpolate => false) { run = true }

      @set.alias_command 'bar', 'foo'
      @set.commands['bar'].options[:shellwords].should == @set.commands['foo'].options[:shellwords]
      @set.commands['bar'].options[:interpolate].should == @set.commands['foo'].options[:interpolate]

      # however some options should not be inherited
      @set.commands['bar'].options[:listing].should.not ==  @set.commands['foo'].options[:listing]
      @set.commands['bar'].options[:listing].should == "bar"
    end

    it 'should be able to specify alias\'s description when aliasing' do
      run = false
      @set.command('foo', 'stuff') { run = true }

      @set.alias_command 'bar', 'foo', :desc => "tobina"
      @set.commands['bar'].match.should == 'bar'
      @set.commands['bar'].description.should == "tobina"

      @set.run_command @ctx, 'bar'
      run.should == true
    end

    it "should be able to alias a command by its invocation line" do
      run = false
      @set.command(/^foo1/, 'stuff', :listing => 'foo') { run = true }

      @set.alias_command 'bar', 'foo1'
      @set.commands['bar'].match.should == 'bar'
      @set.commands['bar'].description.should == 'Alias for `foo1`'

      @set.run_command @ctx, 'bar'
      run.should == true
    end

    it "should be able to specify options when creating alias" do
      run = false
      @set.command(/^foo1/, 'stuff', :listing => 'foo') { run = true }

      @set.alias_command /^b.r/, 'foo1', :listing => "bar"
      @set.commands[/^b.r/].options[:listing].should == "bar"
    end

    it "should set description to default if description parameter is nil" do
      run = false
      @set.command(/^foo1/, 'stuff', :listing => 'foo') { run = true }

      @set.alias_command "bar", 'foo1'
      @set.commands["bar"].description.should == "Alias for `foo1`"
    end
  end

  it 'should be able to change the descriptions of commands' do
    @set.command('foo', 'bar') {}
    @set.desc 'foo', 'baz'

    @set.commands['foo'].description.should == 'baz'
  end

  it 'should get the descriptions of commands' do
    @set.command('foo', 'bar') {}
    @set.desc('foo').should == 'bar'
  end

  it 'should get the descriptions of commands, by listing' do
    @set.command(/^foo1/, 'bar', :listing => 'foo') {}
    @set.desc('foo').should == 'bar'
  end

  it 'should return Pry::Command::VOID_VALUE for commands by default' do
    @set.command('foo') { 3 }
    @set.run_command(@ctx, 'foo').should == Pry::Command::VOID_VALUE
  end

  it 'should be able to keep return values' do
    @set.command('foo', '', :keep_retval => true) { 3 }
    @set.run_command(@ctx, 'foo').should == 3
  end

  it 'should be able to keep return values, even if return value is nil' do
    @set.command('foo', '', :keep_retval => true) { nil }
    @set.run_command(@ctx, 'foo').should == nil
  end

  it 'should be able to have its own helpers' do
    @set.command('foo') do
      should.respond_to :my_helper
    end

    @set.helpers do
      def my_helper; end
    end

    @set.run_command(@ctx, 'foo')
    Pry::Command.subclass('foo', '', {}, Module.new).new({:target => binding}).should.not.respond_to :my_helper
  end

  it 'should not recreate a new helper module when helpers is called' do
    @set.command('foo') do
      should.respond_to :my_helper
      should.respond_to :my_other_helper
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
    @set.command('foo') { should.respond_to :imported_helper_method }
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
    @set.command('foo') { should.respond_to :imported_helper_method }
    @set.run_command(@ctx, 'foo')
  end

  it 'should provide a :listing for a command that defaults to its name' do
    @set.command 'foo', "" do;end
    @set.commands['foo'].options[:listing].should == 'foo'
  end

  it 'should provide a :listing for a command that differs from its name' do
    @set.command 'foo', "", :listing => 'bar' do;end
    @set.commands['foo'].options[:listing].should == 'bar'
  end

  it "should provide a 'help' command" do
    @ctx[:command_set] = @set
    @ctx[:output] = StringIO.new

    lambda {
      @set.run_command(@ctx, 'help')
    }.should.not.raise
  end


  describe "renaming a command" do
    it 'should be able to rename and run a command' do
      run = false
      @set.command('foo') { run = true }
      @set.rename_command('bar', 'foo')
      @set.run_command(@ctx, 'bar')
      run.should == true
    end

    it 'should accept listing name when renaming a command' do
      run = false
      @set.command('foo', "", :listing => 'love') { run = true }
      @set.rename_command('bar', 'love')
      @set.run_command(@ctx, 'bar')
      run.should == true
    end

    it 'should raise exception trying to rename non-existent command' do
      lambda { @set.rename_command('bar', 'foo') }.should.raise ArgumentError
    end

    it 'should make old command name inaccessible' do
      @set.command('foo') { }
      @set.rename_command('bar', 'foo')
      lambda { @set.run_command(@ctx, 'foo') }.should.raise Pry::NoCommandError
    end

    it 'should be able to pass in options when renaming command' do
      desc    = "hello"
      listing = "bing"
      @set.command('foo') { }
      @set.rename_command('bar', 'foo', :description => desc, :listing => listing, :keep_retval => true)
      @set.commands['bar'].description.should           == desc
      @set.commands['bar'].options[:listing].should     == listing
      @set.commands['bar'].options[:keep_retval].should == true
    end
  end

  describe "command decorators - before_command and after_command" do
    describe "before_command" do
      it 'should be called before the original command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.run_command(@ctx, 'foo')

        foo.should == [2, 1]
      end

      it 'should be called before the original command, using listing name' do
        foo = []
        @set.command(/^foo1/, '', :listing => 'foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.run_command(@ctx, /^foo1/)

        foo.should == [2, 1]
      end

      it 'should share the context with the original command' do
        @ctx[:target] = "test target string".__binding__
        before_val  = nil
        orig_val    = nil
        @set.command('foo') { orig_val = target }
        @set.before_command('foo') { before_val = target }
        @set.run_command(@ctx, 'foo')

        before_val.should == @ctx[:target]
        orig_val.should == @ctx[:target]
      end

      it 'should work when applied multiple times' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.before_command('foo') { foo << 2 }
        @set.before_command('foo') { foo << 3 }
        @set.before_command('foo') { foo << 4 }
        @set.run_command(@ctx, 'foo')

        foo.should == [4, 3, 2, 1]
      end

    end

    describe "after_command" do
      it 'should be called after the original command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.run_command(@ctx, 'foo')

        foo.should == [1, 2]
      end

      it 'should be called after the original command, using listing name' do
        foo = []
        @set.command(/^foo1/, '', :listing => 'foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.run_command(@ctx, /^foo1/)

        foo.should == [1, 2]
      end

      it 'should share the context with the original command' do
        @ctx[:target] = "test target string".__binding__
        after_val   = nil
        orig_val    = nil
        @set.command('foo') { orig_val = target }
        @set.after_command('foo') { after_val = target }
        @set.run_command(@ctx, 'foo')

        after_val.should == @ctx[:target]
        orig_val.should == @ctx[:target]
      end

      it 'should determine the return value for the command' do
        @set.command('foo', 'bar', :keep_retval => true) { 1 }
        @set.after_command('foo') { 2 }
        @set.run_command(@ctx, 'foo').should == 2
      end

      it 'should work when applied multiple times' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.after_command('foo') { foo << 3 }
        @set.after_command('foo') { foo << 4 }
        @set.run_command(@ctx, 'foo')

        foo.should == [1, 2, 3, 4]
      end
    end

    describe "before_command and after_command" do
      it 'should work when combining both before_command and after_command' do
        foo = []
        @set.command('foo') { foo << 1 }
        @set.after_command('foo') { foo << 2 }
        @set.before_command('foo') { foo << 3 }
        @set.run_command(@ctx, 'foo')

        foo.should == [3, 1, 2]
      end

    end

  end

  describe 'find_command' do
    it 'should find commands with the right string' do
      cmd = @set.command('rincewind'){ }
      @set.find_command('rincewind').should == cmd
    end

    it 'should not find commands with spaces before' do
      cmd = @set.command('luggage'){ }
      @set.find_command(' luggage').should == nil
    end

    it 'should find commands with arguments after' do
      cmd = @set.command('vetinari'){ }
      @set.find_command('vetinari --knock 3').should == cmd
    end

    it 'should find commands with names containing spaces' do
      cmd = @set.command('nobby nobbs'){ }
      @set.find_command('nobby nobbs --steal petty-cash').should == cmd
    end

    it 'should find command defined by regex' do
      cmd = @set.command(/(capt|captain) vimes/i){ }
      @set.find_command('Capt Vimes').should == cmd
    end

    it 'should find commands defined by regex with arguments' do
      cmd = @set.command(/(cpl|corporal) Carrot/i){ }
      @set.find_command('cpl carrot --write-home').should == cmd
    end

    it 'should not find commands by listing' do
      cmd = @set.command(/werewol(f|ve)s?/, 'only once a month', :listing => "angua"){ }
      @set.find_command('angua').should == nil
    end

    it 'should not find commands without command_prefix' do
      Pry.config.command_prefix = '%'
      cmd = @set.command('detritus'){ }
      @set.find_command('detritus').should == nil
      Pry.config.command_prefix = ''
    end

    it "should find commands that don't use the prefix" do
      Pry.config.command_prefix = '%'
      cmd = @set.command('colon', 'Sergeant Fred', :use_prefix => false){ }
      @set.find_command('colon').should == cmd
      Pry.config.command_prefix = ''
    end

    it "should find the command that has the longest match" do
      cmd = @set.command(/\.(.*)/){ }
      cmd2 = @set.command(/\.\|\|(.*)/){ }
      @set.find_command('.||').should == cmd2
    end

    it "should find the command that has the longest name" do
      cmd = @set.command(/\.(.*)/){ }
      cmd2 = @set.command('.||'){ }
      @set.find_command('.||').should == cmd2
    end
  end

  describe '.valid_command?' do
    it 'should be true for commands that can be found' do
      cmd = @set.command('archchancellor')
      @set.valid_command?('archchancellor of_the?(:University)').should == true
    end

    it 'should be false for commands that can\'' do
      @set.valid_command?('def monkey(ape)').should == false
    end

    it 'should not cause argument interpolation' do
      cmd = @set.command('hello')
      lambda {
        @set.valid_command?('hello #{raise "futz"}')
      }.should.not.raise
    end
  end

  describe '.process_line' do

    it 'should return Result.new(false) if there is no matching command' do
     result = @set.process_line('1 + 42')
     result.command?.should == false
     result.void_command?.should == false
     result.retval.should == nil
    end

    it 'should return Result.new(true, VOID) if the command is not keep_retval' do
      @set.create_command('mrs-cake') do
        def process; 42; end
      end

      result = @set.process_line('mrs-cake')
      result.command?.should == true
      result.void_command?.should == true
      result.retval.should == Pry::Command::VOID_VALUE
    end

    it 'should return Result.new(true, retval) if the command is keep_retval' do
      @set.create_command('magrat', 'the maiden', :keep_retval => true) do
        def process; 42; end
      end

      result = @set.process_line('magrat')
      result.command?.should == true
      result.void_command?.should == false
      result.retval.should == 42
    end

    it 'should pass through context' do
      ctx = {
        :eval_string => "bloomers",
        :pry_instance => Object.new,
        :output => StringIO.new,
        :target => binding
      }
      @set.create_command('agnes') do
        define_method(:process) do
          eval_string.should == ctx[:eval_string]
          output.should == ctx[:output]
          target.should == ctx[:target]
          _pry_.should == ctx[:pry_instance]
        end
      end

      @set.process_line('agnes', ctx)
    end

    it 'should add command_set to context' do
      set = @set
      @set.create_command(/nann+y ogg+/) do
        define_method(:process) do
          command_set.should == set
        end
      end

      @set.process_line('nannnnnny oggggg')
    end
  end

  if defined?(Bond)
    describe '.complete' do
      it "should list all command names" do
        @set.create_command('susan'){ }
        @set.complete('sus').should.include 'susan '
      end

      it "should delegate to commands" do
        @set.create_command('susan'){ def complete(search); ['--foo']; end }
        @set.complete('susan ').should == ['--foo']
      end
    end
  end
end
