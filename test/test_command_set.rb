require 'helper'

describe Pry::CommandSet do
  before do
    @set = Pry::CommandSet.new
  end

  it 'should call the block used for the command when it is called' do
    run = false
    @set.command 'foo' do
      run = true
    end

    @set.run_command nil, 'foo'
    run.should == true
  end

  it 'should pass arguments of the command to the block' do
    @set.command 'foo' do |*args|
      args.should == [1, 2, 3]
    end

    @set.run_command nil, 'foo', 1, 2, 3
  end

  it 'should use the first argument as self' do
    @set.command 'foo' do
      self.should == true
    end

    @set.run_command true, 'foo'
  end

  it 'should raise an error when calling an undefined comand' do
    @set.command('foo') {}
    lambda {
      @set.run_command nil, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to remove its own commands' do
    @set.command('foo') {}
    @set.delete 'foo'

    lambda {
      @set.run_command nil, 'foo'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to import some commands from other sets' do
    run = false

    other_set = Pry::CommandSet.new do
      command('foo') { run = true }
      command('bar') {}
    end

    @set.import_from(other_set, 'foo')

    @set.run_command nil, 'foo'
    run.should == true

    lambda {
      @set.run_command nil, 'bar'
    }.should.raise(Pry::NoCommandError)
  end

  it 'should be able to import a whole set' do
    run = []

    other_set = Pry::CommandSet.new do
      command('foo') { run << true }
      command('bar') { run << true }
    end

    @set.import other_set

    @set.run_command nil, 'foo'
    @set.run_command nil, 'bar'
    run.should == [true, true]
  end

  it 'should be able to import sets at creation' do
    run = false
    @set.command('foo') { run = true }

    Pry::CommandSet.new(@set).run_command nil, 'foo'
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
    @set.commands['bar'].description.should == 'stuff'

    @set.run_command nil, 'bar'
    run.should == true
  end

  it 'should be able to change the descritpions of methods' do
    @set.command('foo', 'bar') {}
    @set.desc 'foo', 'baz'

    @set.commands['foo'].description.should == 'baz'
  end

  it 'should return nil for commands by default' do
    @set.command('foo') { 3 }
    @set.run_command(nil, 'foo').should == nil
  end

  it 'should be able to keep return values' do
    @set.command('foo', '', :keep_retval => true) { 3 }
    @set.run_command(nil, 'foo').should == 3
  end

  it 'should be able to have its own helpers' do
    @set.command('foo') do
      should.respond_to :my_helper
    end

    @set.helpers do
      def my_helper; end
    end

    @set.run_command(Pry::CommandContext.new, 'foo')
    Pry::CommandContext.new.should.not.respond_to :my_helper
  end

  it 'should not recreate a new heler module when helpers is called' do
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

    @set.run_command(Pry::CommandContext.new, 'foo')
  end

  it 'should import helpers from imported sets' do
    imported_set = Pry::CommandSet.new do
      helpers do
        def imported_helper_method; end
      end
    end

    @set.import imported_set
    @set.command('foo') { should.respond_to :imported_helper_method }
    @set.run_command(Pry::CommandContext.new, 'foo')
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
    @set.run_command(Pry::CommandContext.new, 'foo')
  end
end
