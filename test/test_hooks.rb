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

  describe "Pry::Hooks#merge" do
    describe "merge!" do
      it 'should merge in the Pry::Hooks' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        h2 = Pry::Hooks.new

        h2.merge!(h1)
        h2.get_hook(:test_hook, :testing).should == h1.get_hook(:test_hook, :testing)
      end

      it 'should not share merged elements with original' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        h2 = Pry::Hooks.new

        h2.merge!(h1)
        h2.add_hook(:test_hook, :testing2) {}
        h2.get_hook(:test_hook, :testing2).should.not == h1.get_hook(:test_hook, :testing2)
      end

      it 'should NOT overwrite hooks belonging to shared event in receiver' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        callable = proc {}
        h2 = Pry::Hooks.new.add_hook(:test_hook, :testing2, callable)

        h2.merge!(h1)
        h2.get_hook(:test_hook, :testing2).should == callable
      end

      it 'should overwrite identical hook in receiver' do
        callable1 = proc { :one }
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing, callable1)
        callable2 = proc { :two }
        h2 = Pry::Hooks.new.add_hook(:test_hook, :testing, callable2)

        h2.merge!(h1)
        h2.get_hook(:test_hook, :testing).should == callable1
        h2.hook_count(:test_hook).should == 1
      end

      it 'should preserve hook order' do
        name = ""
        h1 = Pry::Hooks.new
        h1.add_hook(:test_hook, :testing3) { name << "h" }
        h1.add_hook(:test_hook, :testing4) { name << "n" }

        h2 = Pry::Hooks.new
        h2.add_hook(:test_hook, :testing1) { name << "j" }
        h2.add_hook(:test_hook, :testing2) { name << "o" }

        h2.merge!(h1)
        h2.exec_hook(:test_hook)

        name.should == "john"
      end

      describe "merge" do
        it 'should return a fresh, independent instance' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new

          h3 = h2.merge(h1)
          h3.should.not == h1
          h3.should.not == h2
        end

        it 'should contain hooks from original instance' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new.add_hook(:test_hook2, :testing) {}

          h3 = h2.merge(h1)
          h3.get_hook(:test_hook, :testing).should == h1.get_hook(:test_hook, :testing)
          h3.get_hook(:test_hook2, :testing).should == h2.get_hook(:test_hook2, :testing)
        end

        it 'should not affect original instances when new hooks are added' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new.add_hook(:test_hook2, :testing) {}

          h3 = h2.merge(h1)
          h3.add_hook(:test_hook3, :testing) {}

          h1.get_hook(:test_hook3, :testing).should == nil
          h2.get_hook(:test_hook3, :testing).should == nil
        end
      end

    end
  end

  describe "dupping a Pry::Hooks instance" do
    it 'should share hooks with original' do
      @hooks.add_hook(:test_hook, :testing) do
        :none_such
      end

      hooks_dup = @hooks.dup
      hooks_dup.get_hook(:test_hook, :testing).should == @hooks.get_hook(:test_hook, :testing)
    end

    it 'adding a new event to dupped instance should not affect original' do
      @hooks.add_hook(:test_hook, :testing) { :none_such }
      hooks_dup = @hooks.dup

      hooks_dup.add_hook(:other_test_hook, :testing) { :okay_man }

      hooks_dup.get_hook(:other_test_hook, :testing).should.not == @hooks.get_hook(:other_test_hook, :testing)
    end

    it 'adding a new hook to dupped instance should not affect original' do
      @hooks.add_hook(:test_hook, :testing) { :none_such }
      hooks_dup = @hooks.dup

      hooks_dup.add_hook(:test_hook, :testing2) { :okay_man }

      hooks_dup.get_hook(:test_hook, :testing2).should.not == @hooks.get_hook(:test_hook, :testing2)
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

    it 'should add exceptions to the errors array' do
      @hooks.add_hook(:test_hook, :foo1) { raise 'one' }
      @hooks.add_hook(:test_hook, :foo2) { raise 'two' }
      @hooks.add_hook(:test_hook, :foo3) { raise 'three' }
      @hooks.exec_hook(:test_hook)
      @hooks.errors.map(&:message).should == ['one', 'two', 'three']
    end

    it 'should return the last exception raised as the return value' do
      @hooks.add_hook(:test_hook, :foo1) { raise 'one' }
      @hooks.add_hook(:test_hook, :foo2) { raise 'two' }
      @hooks.add_hook(:test_hook, :foo3) { raise 'three' }
      @hooks.exec_hook(:test_hook).should == @hooks.errors.last
    end
  end

  describe "integration tests" do
    describe "when_started hook" do
      it 'should yield options to the hook' do
        options = nil
        Pry.config.hooks.add_hook(:when_started, :test_hook) { |target, opt, _| options = opt }

        redirect_pry_io(StringIO.new("exit"), out=StringIO.new) do
          Pry.start binding, :hello => :baby
        end

        options[:hello].should == :baby

        Pry.config.hooks.delete_hook(:when_started, :test_hook)
      end

      describe "target" do

        it 'should yield the target, as a binding ' do
          b = nil
          Pry.config.hooks.add_hook(:when_started, :test_hook) { |target, opt, _| b = target }

          redirect_pry_io(StringIO.new("exit"), out=StringIO.new) do
            Pry.start 5, :hello => :baby
          end

          b.is_a?(Binding).should == true
          Pry.config.hooks.delete_hook(:when_started, :test_hook)
        end

        it 'should yield the target to the hook' do
          b = nil
          Pry.config.hooks.add_hook(:when_started, :test_hook) { |target, opt, _| b = target }

          redirect_pry_io(StringIO.new("exit"), out=StringIO.new) do
            Pry.start 5, :hello => :baby
          end

          b.eval('self').should == 5
          Pry.config.hooks.delete_hook(:when_started, :test_hook)
        end
      end

      it 'should allow overriding of target (and binding_stack)' do
        options = nil
        o = Object.new
        class << o; attr_accessor :value; end

        Pry.config.hooks.add_hook(:when_started, :test_hook) { |target, opt, _pry_| _pry_.binding_stack = [Pry.binding_for(o)] }

        redirect_pry_io(InputTester.new("@value = true","exit-all")) do
          Pry.start binding, :hello => :baby
        end

        o.value.should == true
        Pry.config.hooks.delete_hook(:when_started, :test_hook)
      end

    end

    describe "after_session hook" do
      it 'should always run, even if uncaught exception bubbles out of repl' do
        o = OpenStruct.new
        o.great_escape = Class.new(StandardError)

        old_ew = Pry.config.exception_whitelist
        Pry.config.exception_whitelist << o.great_escape

        array = [1, 2, 3, 4, 5]

        begin
          redirect_pry_io(StringIO.new("raise great_escape"), out=StringIO.new) do
            Pry.start o, :hooks => Pry::Hooks.new.add_hook(:after_session, :cleanup) { array = nil }
          end
        rescue => ex
          exception = ex
        end

        # ensure that an exception really was raised and it broke out
        # of the repl
        exception.is_a?(o.great_escape).should == true

        # check that after_session hook ran
        array.should == nil

        # cleanup after test
        Pry.config.exception_whitelist = old_ew
      end

      describe "before_eval hook" do
        describe "modifying input code" do
          it 'should replace input code with code determined by hook' do
            hooks = Pry::Hooks.new.add_hook(:before_eval, :quirk) { |code, pry| code.replace(":little_duck") }
            redirect_pry_io(InputTester.new(":jemima", "exit-all"), out = StringIO.new) do
              Pry.start(self, :hooks => hooks)
            end
            out.string.should =~ /little_duck/
            out.string.should.not =~ /jemima/
          end

          it 'should not interfere with command processing when replacing input code' do
            commands = Pry::CommandSet.new do
              import_from Pry::Commands, "exit-all"

              command "how-do-you-like-your-blue-eyed-boy-now-mister-death" do
                output.puts "in hours of bitterness i imagine balls of sapphire, of metal"
              end
            end

            hooks = Pry::Hooks.new.add_hook(:before_eval, :quirk) { |code, pry| code.replace(":little_duck") }
            redirect_pry_io(InputTester.new("how-do-you-like-your-blue-eyed-boy-now-mister-death", "exit-all"), out = StringIO.new) do
              Pry.start(self, :hooks => hooks, :commands => commands)
            end
            out.string.should =~ /in hours of bitterness i imagine balls of sapphire, of metal/
            out.string.should.not =~ /little_duck/
          end
        end

      end

      describe "exceptions" do
        before do
          Pry.config.hooks.add_hook(:after_eval, :baddums){ raise "Baddums" }
          Pry.config.hooks.add_hook(:after_eval, :simbads){ raise "Simbads" }
        end

        after do
          Pry.config.hooks.delete_hook(:after_eval, :baddums)
          Pry.config.hooks.delete_hook(:after_eval, :simbads)
        end
        it "should not raise exceptions" do
          lambda{
            mock_pry("1", "2", "3")
          }.should.not.raise
        end

        it "should print out a notice for each exception raised" do
          mock_pry("1").should =~ /after_eval hook failed: RuntimeError: Baddums\n.*after_eval hook failed: RuntimeError: Simbads/m
        end
      end
    end
  end

  describe "anonymous hooks" do
    it 'should allow adding of hook without a name' do
      @hooks.add_hook(:test_hook, nil) {}
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should only allow one anonymous hook to exist' do
      @hooks.add_hook(:test_hook, nil) {  }
      @hooks.add_hook(:test_hook, nil) {  }
      @hooks.hook_count(:test_hook).should == 1
    end

    it 'should execute most recently added anonymous hook' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook, nil) { y = 1 }
      @hooks.add_hook(:test_hook, nil) { x = 2 }
      @hooks.exec_hook(:test_hook)
      y.should == nil
      x.should == 2
    end
  end

  describe "deprecated hash-based API" do
    after do
      Pry.config.hooks.clear_all if Pry.config.hooks
    end

    describe "Pry.config.hooks" do
      it 'should allow a hash-assignment' do
        Pry.config.hooks = { :before_session => proc { :hello } }
        Pry.config.hooks.get_hook(:before_session, nil).call.should == :hello
      end

      describe "Pry.config.hooks[]" do
        it 'should return the only anonymous hook' do
          Pry.config.hooks = { :before_session => proc { :hello } }
          Pry.config.hooks[:before_session].call.should == :hello
        end

        it 'should add an anonymous hook when using Pry.config.hooks[]=' do
          Pry.config.hooks[:before_session] = proc { :bing }
          Pry.config.hooks.hook_count(:before_session).should == 1
        end

        it 'should add overwrite previous anonymous hooks with new one when calling Pry.config.hooks[]= multiple times' do
          x = nil
          Pry.config.hooks[:before_session] = proc { x = 1 }
          Pry.config.hooks[:before_session] = proc { x = 2 }

          Pry.config.hooks.exec_hook(:before_session)
          Pry.config.hooks.hook_count(:before_session).should == 1
          x.should == 2
        end
      end
    end

    describe "Pry.start" do
      it 'should accept a hash for :hooks parameter' do

        redirect_pry_io(InputTester.new("exit-all"), out=StringIO.new) do
          Pry.start binding, :hooks => { :before_session => proc { |output, _, _| output.puts 'hello friend' } }
        end

        out.string.should =~ /hello friend/
      end

    end
  end

end
