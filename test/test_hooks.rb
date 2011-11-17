require 'helper'

describe Pry::Hooks do
  before do
    @hooks = Pry::Hooks.new
  end

  describe "adding a new hook" do
    it 'should not execute hook while adding it' do
      @hooks.add_hook(:test_hook, :my_name) { @test_var = true }
      @test_var.should == nil
    end

    it 'should return a count of 0 for an empty hook' do
      @hooks.hook_count(:test_hook).should == 0
    end

    it 'should create a new hook with a block' do
      @hooks.add_hook(:test_hook, :my_name) { }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should create a new hook with a callable' do
      @hooks.add_hook(:test_hook, :my_name, proc { })
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should use just block if given both block and callable' do
      @hooks.add_hook(:test_hook, :my_name, proc { }) { }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should raise if not given a block or any other object' do
      lambda { @hooks.add_hook(:test_hook, :my_name) }.should.raise ArgumentError
    end

    it 'should create a hook with multiple callables' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.add_hook(:test_hook, :my_name2) {}
      @hooks.hook_count(:test_hook).should == 2
    end
  end

  describe "getting a hook" do
    it 'should return the correct requested hook' do
      run = false
      fun = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.add_hook(:test_hook, :my_name2) { fun = true }
      @hooks.get_hook(:test_hook, :my_name).call
      run.should == true
      fun.should == false
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
    it 'should successfully delete a hook function' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.delete_hook(:test_hook, :my_name)
      @hooks.hook_count(:test_hook).should == 0
    end

    it 'should return the deleted hook function' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.delete_hook(:test_hook, :my_name).call
      run.should == true
    end
  end

  describe "executing a hook" do
    before do
      @test_var = nil
    end

    it 'should execute block hook' do
      @hooks.add_hook(:test_hook, :my_name) { @test_var = true }
      @hooks.exec_hook(:test_hook)
      @test_var.should == true
    end

    it 'should execute proc hook' do
      @hooks.add_hook(:test_hook, :my_name, proc { @test_var = true })
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

      @hooks.add_hook(:test_hook, :my_name, callable)
      @hooks.exec_hook(:test_hook)
      callable.test_var.should == true
    end

    it 'should execute multiple callables for a hook if more than one is defined' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook, :my_name2) { x = true }
      @hooks.add_hook(:test_hook, :my_name) { y = true }
      @hooks.exec_hook(:test_hook)
      x.should == true
      y.should == true
    end
  end
end
