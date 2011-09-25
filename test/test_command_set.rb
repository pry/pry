require 'helper'

describe Pry::CommandSet do
  before do
    @set = Pry::CommandSet.new
    @ctx = Pry::CommandContext.new
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

  it 'should use the first argument as self' do
    ctx = @ctx

    @set.command 'foo' do
      self.should == ctx
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

  it 'should be able to alias method' do
    run = false
    @set.command('foo', 'stuff') { run = true }

    @set.alias_command 'bar', 'foo'
    @set.commands['bar'].name.should == 'bar'
    @set.commands['bar'].description.should == ''

    @set.run_command @ctx, 'bar'
    run.should == true
  end

  it 'should be able to change the descritpions of methods' do
    @set.command('foo', 'bar') {}
    @set.desc 'foo', 'baz'

    @set.commands['foo'].description.should == 'baz'
  end

  it 'should return Pry::CommandContext::VOID_VALUE for commands by default' do
    @set.command('foo') { 3 }
    @set.run_command(@ctx, 'foo').should == Pry::CommandContext::VOID_VALUE
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
    Pry::CommandContext.new.should.not.respond_to :my_helper
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
    @ctx.command_set = @set
    @ctx.output = StringIO.new

    lambda {
      @set.run_command(@ctx, 'help')
    }.should.not.raise
  end

  it "should sort the output of the 'help' command" do
    @set.command 'foo', "Fooerizes" do; end
    @set.command 'goo', "Gooerizes" do; end
    @set.command 'moo', "Mooerizes" do; end
    @set.command 'boo', "Booerizes" do; end

    @ctx.command_set = @set
    @ctx.output = StringIO.new

    @set.run_command(@ctx, 'help')

    doc = @ctx.output.string

    order = [doc.index("boo"),
             doc.index("foo"),
             doc.index("goo"),
             doc.index("help"),
             doc.index("moo")]

    order.should == order.sort
  end
end
