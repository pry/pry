require 'helper'

describe Pry::Hooks do
  before do
    @hooks    = Pry::Hooks.new
  end

  describe "adding a new hook" do
    it 'should not execute hook while adding it' do
      @hooks.add_hook(:test_hook) { @test_var = true }
      @test_var.should == nil
    end

    it 'should return a count of 0 for an empty hook' do
      @hooks.hook_count(:test_hook).should == 0
    end

    it 'should create a new hook with a block' do
      @hooks.add_hook(:test_hook) { }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should create a new hook with a callable' do
      @hooks.add_hook(:test_hook, proc { })
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should use just block if given both block and callable' do
      @hooks.add_hook(:test_hook, proc { }) { }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should raise if not given a block or any other object' do
      lambda { @hooks.add_hook(:test_hook) }.should.raise ArgumentError
    end

    it 'should create a hook with multiple callables' do
      @hooks.add_hook(:test_hook) {}
      @hooks.add_hook(:test_hook) {}
      @hooks.hook_count(:test_hook).should == 2
    end
  end

  describe "executing a hook" do
    before do
      @test_var = nil
    end

    it 'should execute block hook' do
      @hooks.add_hook(:test_hook) { @test_var = true }
      @hooks.exec_hook(:test_hook)
      @test_var.should == true
    end

    it 'should execute proc hook' do
      @hooks.add_hook(:test_hook, proc { @test_var = true })
      @hooks.exec_hook(:test_hook)
      @test_var.should == true
    end

    it 'should execute a general callable hook' do
      callable = Object.new.tap do |obj|
        obj.instance_variable_set(:@test_var, nil)
        class << obj
          attr_accessor :test_var
          def call() @test_var = true; end
        end
      end

      @hooks.add_hook(:test_hook, callable)
      @hooks.exec_hook(:test_hook)
      callable.test_var.should == true
    end

    it 'should execute multiple callables for a hook if more than one is defined' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook) { x = true }
      @hooks.add_hook(:test_hook) { y = true }
      @hooks.exec_hook(:test_hook)
      x.should == true
      y.should == true
    end
  end
end
