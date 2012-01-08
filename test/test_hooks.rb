require 'helper'

describe Pry::Hooks do
  before do
    @hooks = Pry::Hooks.new
  end

  describe "adding a new hook" do
    it 'should not execute hook while adding it' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      run.should == false
    end

    it 'should not allow adding of a hook with a duplicate name' do
      @hooks.add_hook(:test_hook, :my_name) {}

      lambda { @hooks.add_hook(:test_hook, :my_name) {} }.should.raise ArgumentError
    end

    it 'should create a new hook with a block' do
      @hooks.add_hook(:test_hook, :my_name) { }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should create a new hook with a callable' do
      @hooks.add_hook(:test_hook, :my_name, proc { })
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should use block if given both block and callable' do
      run = false
      foo = false
      @hooks.add_hook(:test_hook, :my_name, proc { foo = true }) { run = true }
      @hooks.hook_count(:test_hook).should == 1
      @hooks.exec_hook(:test_hook)
      run.should == true
      foo.should == false
    end

    it 'should raise if not given a block or any other object' do
      lambda { @hooks.add_hook(:test_hook, :my_name) }.should.raise ArgumentError
    end

    it 'should create multiple hooks for an event' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.add_hook(:test_hook, :my_name2) {}
      @hooks.hook_count(:test_hook).should == 2
    end

    it 'should return a count of 0 for an empty hook' do
      @hooks.hook_count(:test_hook).should == 0
    end
  end

  describe "getting hooks" do
    describe "get_hook" do
      it 'should return the correct requested hook' do
        run = false
        fun = false
        @hooks.add_hook(:test_hook, :my_name) { run = true }
        @hooks.add_hook(:test_hook, :my_name2) { fun = true }
        @hooks.get_hook(:test_hook, :my_name).call
        run.should == true
        fun.should == false
      end

      it 'should return nil if hook does not exist' do
        @hooks.get_hook(:test_hook, :my_name).should == nil
      end
    end

    describe "get_hooks" do
      it 'should return a hash of hook names/hook functions for an event' do
        hook1 = proc { 1 }
        hook2 = proc { 2 }
        @hooks.add_hook(:test_hook, :my_name1, hook1)
        @hooks.add_hook(:test_hook, :my_name2, hook2)
        hash = @hooks.get_hooks(:test_hook)
        hash.size.should == 2
        hash[:my_name1].should == hook1
        hash[:my_name2].should == hook2
      end

      it 'should return an empty hash if no hooks defined' do
        @hooks.get_hooks(:test_hook).should == {}
      end
    end
  end

  describe "clearing all hooks for an event" do
    it 'should clear all hooks' do
      @hooks.add_hook(:test_hook, :my_name) { }
      @hooks.add_hook(:test_hook, :my_name2) { }
      @hooks.add_hook(:test_hook, :my_name3) { }
      @hooks.clear(:test_hook)
      @hooks.hook_count(:test_hook).should == 0
    end
  end

  describe "deleting a hook" do
    it 'should successfully delete a hook' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.delete_hook(:test_hook, :my_name)
      @hooks.hook_count(:test_hook).should == 0
    end

    it 'should return the deleted hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.delete_hook(:test_hook, :my_name).call
      run.should == true
    end

    it 'should return nil if hook does not exist' do
      @hooks.delete_hook(:test_hook, :my_name).should == nil
    end
  end

  describe "executing a hook" do
    it 'should execute block hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.exec_hook(:test_hook)
      run.should == true
    end

    it 'should execute proc hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name, proc { run = true })
      @hooks.exec_hook(:test_hook)
      run.should == true
    end

    it 'should execute a general callable hook' do
      callable = Object.new.tap do |obj|
        obj.instance_variable_set(:@test_var, nil)
        class << obj
          attr_accessor :test_var
          def call() @test_var = true; end
        end
      end

      @hooks.add_hook(:test_hook, :my_name, callable)
      @hooks.exec_hook(:test_hook)
      callable.test_var.should == true
    end

    it 'should execute all hooks for an event if more than one is defined' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook, :my_name1) { y = true }
      @hooks.add_hook(:test_hook, :my_name2) { x = true }
      @hooks.exec_hook(:test_hook)
      x.should == true
      y.should == true
    end

    it 'should execute hooks in order' do
      array = []
      @hooks.add_hook(:test_hook, :my_name1) { array << 1 }
      @hooks.add_hook(:test_hook, :my_name2) { array << 2 }
      @hooks.add_hook(:test_hook, :my_name3) { array << 3 }
      @hooks.exec_hook(:test_hook)
      array.should == [1, 2, 3]
    end

    it 'return value of exec_hook should be that of last executed hook' do
      @hooks.add_hook(:test_hook, :my_name1) { 1 }
      @hooks.add_hook(:test_hook, :my_name2) { 2 }
      @hooks.add_hook(:test_hook, :my_name3) { 3 }
      @hooks.exec_hook(:test_hook).should == 3
    end
  end

  describe "integration tests" do
    describe "when_started hook" do
      it 'should yield options to the hook' do
        options = nil
        Pry.config.hooks.add_hook(:when_started, :test_hook) { |_, opt, _| options = opt }

        redirect_pry_io(StringIO.new("exit"), out=StringIO.new) do
          Pry.start binding, :hello => :baby
        end
        options[:hello].should == :baby

        Pry.config.hooks.delete_hook(:when_started, :test_hook)
      end
    end
  end
end
