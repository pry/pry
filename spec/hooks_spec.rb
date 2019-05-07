# frozen_string_literal: true

describe Pry::Hooks do
  before do
    @hooks = Pry::Hooks.new
  end

  describe ".default" do
    it "returns hooks with default before_session hook" do
      hooks = described_class.default
      expect(hooks.hook_exists?('before_session', :default)).to be_truthy
    end

    context "when pry instance is quiet" do
      let(:pry_instance) { Pry.new(quiet: true) }

      it "doesn't run the whereami command" do
        expect(pry_instance).not_to receive(:run_command)
        hooks = described_class.default
        hooks.exec_hook(:before_session, StringIO.new, {}, pry_instance)
      end
    end

    context "when pry instance is not quiet" do
      let(:pry_instance) { Pry.new(quiet: false) }
      let(:output) { StringIO.new }

      it "runs the whereami command" do
        expect(pry_instance).to receive(:run_command).with('whereami --quiet')
        hooks = described_class.default
        hooks.exec_hook(:before_session, StringIO.new, {}, pry_instance)
      end
    end
  end

  describe "adding a new hook" do
    it 'should not execute hook while adding it' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      expect(run).to eq false
    end

    it 'should not allow adding of a hook with a duplicate name' do
      @hooks.add_hook(:test_hook, :my_name) {}

      expect { @hooks.add_hook(:test_hook, :my_name) {} }.to raise_error ArgumentError
    end

    it 'should create a new hook with a block' do
      @hooks.add_hook(:test_hook, :my_name) {}
      expect(@hooks.hook_count(:test_hook)).to eq 1
    end

    it 'should create a new hook with a callable' do
      @hooks.add_hook(:test_hook, :my_name, proc {})
      expect(@hooks.hook_count(:test_hook)).to eq 1
    end

    it 'should use block if given both block and callable' do
      run = false
      foo = false
      @hooks.add_hook(:test_hook, :my_name, proc { foo = true }) { run = true }
      expect(@hooks.hook_count(:test_hook)).to eq 1
      @hooks.exec_hook(:test_hook)
      expect(run).to eq true
      expect(foo).to eq false
    end

    it 'should raise if not given a block or any other object' do
      expect { @hooks.add_hook(:test_hook, :my_name) }.to raise_error ArgumentError
    end

    it 'should create multiple hooks for an event' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.add_hook(:test_hook, :my_name2) {}
      expect(@hooks.hook_count(:test_hook)).to eq 2
    end

    it 'should return a count of 0 for an empty hook' do
      expect(@hooks.hook_count(:test_hook)).to eq 0
    end
  end

  describe "Pry::Hooks#merge" do
    describe "merge!" do
      it 'should merge in the Pry::Hooks' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        h2 = Pry::Hooks.new

        h2.merge!(h1)
        expect(h2.get_hook(:test_hook, :testing)).to eq h1.get_hook(:test_hook, :testing)
      end

      it 'should not share merged elements with original' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        h2 = Pry::Hooks.new

        h2.merge!(h1)
        h2.add_hook(:test_hook, :testing2) {}
        expect(h2.get_hook(:test_hook, :testing2)).not_to eq(
          h1.get_hook(:test_hook, :testing2)
        )
      end

      it 'should NOT overwrite hooks belonging to shared event in receiver' do
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
        callable = proc {}
        h2 = Pry::Hooks.new.add_hook(:test_hook, :testing2, callable)

        h2.merge!(h1)
        expect(h2.get_hook(:test_hook, :testing2)).to eq callable
      end

      it 'should overwrite identical hook in receiver' do
        callable1 = proc { :one }
        h1 = Pry::Hooks.new.add_hook(:test_hook, :testing, callable1)
        callable2 = proc { :two }
        h2 = Pry::Hooks.new.add_hook(:test_hook, :testing, callable2)

        h2.merge!(h1)
        expect(h2.get_hook(:test_hook, :testing)).to eq callable1
        expect(h2.hook_count(:test_hook)).to eq 1
      end

      it 'should preserve hook order' do
        name = ''
        h1 = Pry::Hooks.new
        h1.add_hook(:test_hook, :testing3) { name += "h" }
        h1.add_hook(:test_hook, :testing4) { name += "n" }

        h2 = Pry::Hooks.new
        h2.add_hook(:test_hook, :testing1) { name += "j" }
        h2.add_hook(:test_hook, :testing2) { name += "o" }

        h2.merge!(h1)
        h2.exec_hook(:test_hook)

        expect(name).to eq "john"
      end

      describe "merge" do
        it 'should return a fresh, independent instance' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new

          h3 = h2.merge(h1)
          expect(h3).not_to eq h1
          expect(h3).not_to eq h2
        end

        it 'should contain hooks from original instance' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new.add_hook(:test_hook2, :testing) {}

          h3 = h2.merge(h1)
          expect(h3.get_hook(:test_hook, :testing)).to eq(
            h1.get_hook(:test_hook, :testing)
          )
          expect(h3.get_hook(:test_hook2, :testing)).to eq(
            h2.get_hook(:test_hook2, :testing)
          )
        end

        it 'should not affect original instances when new hooks are added' do
          h1 = Pry::Hooks.new.add_hook(:test_hook, :testing) {}
          h2 = Pry::Hooks.new.add_hook(:test_hook2, :testing) {}

          h3 = h2.merge(h1)
          h3.add_hook(:test_hook3, :testing) {}

          expect(h1.get_hook(:test_hook3, :testing)).to eq nil
          expect(h2.get_hook(:test_hook3, :testing)).to eq nil
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
      expect(hooks_dup.get_hook(:test_hook, :testing)).to eq(
        @hooks.get_hook(:test_hook, :testing)
      )
    end

    it 'adding a new event to dupped instance should not affect original' do
      @hooks.add_hook(:test_hook, :testing) { :none_such }
      hooks_dup = @hooks.dup

      hooks_dup.add_hook(:other_test_hook, :testing) { :okay_man }

      expect(hooks_dup.get_hook(:other_test_hook, :testing))
        .not_to eq @hooks.get_hook(:other_test_hook, :testing)
    end

    it 'adding a new hook to dupped instance should not affect original' do
      @hooks.add_hook(:test_hook, :testing) { :none_such }
      hooks_dup = @hooks.dup

      hooks_dup.add_hook(:test_hook, :testing2) { :okay_man }

      expect(hooks_dup.get_hook(:test_hook, :testing2))
        .not_to eq @hooks.get_hook(:test_hook, :testing2)
    end
  end

  describe "getting hooks" do
    describe "get_hook" do
      it 'should return the correct requested hook' do
        run1 = false
        run2 = false
        @hooks.add_hook(:test_hook, :my_name) { run1 = true }
        @hooks.add_hook(:test_hook, :my_name2) { run2 = true }
        @hooks.get_hook(:test_hook, :my_name).call
        expect(run1).to eq true
        expect(run2).to eq false
      end

      it 'should return nil if hook does not exist' do
        expect(@hooks.get_hook(:test_hook, :my_name)).to eq nil
      end
    end

    describe "get_hooks" do
      it 'should return a hash of hook names/hook functions for an event' do
        hook1 = proc { 1 }
        hook2 = proc { 2 }
        @hooks.add_hook(:test_hook, :my_name1, hook1)
        @hooks.add_hook(:test_hook, :my_name2, hook2)
        hash = @hooks.get_hooks(:test_hook)
        expect(hash.size).to eq 2
        expect(hash[:my_name1]).to eq hook1
        expect(hash[:my_name2]).to eq hook2
      end

      it 'should return an empty hash if no hooks defined' do
        expect(@hooks.get_hooks(:test_hook)).to eq({})
      end
    end
  end

  describe "clearing all hooks for an event" do
    it 'should clear all hooks' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.add_hook(:test_hook, :my_name2) {}
      @hooks.add_hook(:test_hook, :my_name3) {}
      @hooks.clear_event_hooks(:test_hook)
      expect(@hooks.hook_count(:test_hook)).to eq 0
    end
  end

  describe "deleting a hook" do
    it 'should successfully delete a hook' do
      @hooks.add_hook(:test_hook, :my_name) {}
      @hooks.delete_hook(:test_hook, :my_name)
      expect(@hooks.hook_count(:test_hook)).to eq 0
    end

    it 'should return the deleted hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.delete_hook(:test_hook, :my_name).call
      expect(run).to eq true
    end

    it 'should return nil if hook does not exist' do
      expect(@hooks.delete_hook(:test_hook, :my_name)).to eq nil
    end
  end

  describe "executing a hook" do
    it 'should execute block hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name) { run = true }
      @hooks.exec_hook(:test_hook)
      expect(run).to eq true
    end

    it 'should execute proc hook' do
      run = false
      @hooks.add_hook(:test_hook, :my_name, proc { run = true })
      @hooks.exec_hook(:test_hook)
      expect(run).to eq true
    end

    it 'should execute a general callable hook' do
      callable = Object.new.tap do |obj|
        obj.instance_variable_set(:@test_var, nil)
        class << obj
          attr_accessor :test_var
          def call
            @test_var = true
          end
        end
      end

      @hooks.add_hook(:test_hook, :my_name, callable)
      @hooks.exec_hook(:test_hook)
      expect(callable.test_var).to eq true
    end

    it 'should execute all hooks for an event if more than one is defined' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook, :my_name1) { y = true }
      @hooks.add_hook(:test_hook, :my_name2) { x = true }
      @hooks.exec_hook(:test_hook)
      expect(x).to eq true
      expect(y).to eq true
    end

    it 'should execute hooks in order' do
      array = []
      @hooks.add_hook(:test_hook, :my_name1) { array << 1 }
      @hooks.add_hook(:test_hook, :my_name2) { array << 2 }
      @hooks.add_hook(:test_hook, :my_name3) { array << 3 }
      @hooks.exec_hook(:test_hook)
      expect(array).to eq [1, 2, 3]
    end

    it 'return value of exec_hook should be that of last executed hook' do
      @hooks.add_hook(:test_hook, :my_name1) { 1 }
      @hooks.add_hook(:test_hook, :my_name2) { 2 }
      @hooks.add_hook(:test_hook, :my_name3) { 3 }
      expect(@hooks.exec_hook(:test_hook)).to eq 3
    end

    it 'should add exceptions to the errors array' do
      @hooks.add_hook(:test_hook, :foo1) { raise 'one' }
      @hooks.add_hook(:test_hook, :foo2) { raise 'two' }
      @hooks.add_hook(:test_hook, :foo3) { raise 'three' }
      @hooks.exec_hook(:test_hook)
      expect(@hooks.errors.map(&:message)).to eq %w[one two three]
    end

    it 'should return the last exception raised as the return value' do
      @hooks.add_hook(:test_hook, :foo1) { raise 'one' }
      @hooks.add_hook(:test_hook, :foo2) { raise 'two' }
      @hooks.add_hook(:test_hook, :foo3) { raise 'three' }
      expect(@hooks.exec_hook(:test_hook)).to eq @hooks.errors.last
    end
  end

  describe "integration tests" do
    describe "when_started hook" do
      it 'should yield options to the hook' do
        options = nil
        Pry.config.hooks.add_hook(:when_started, :test_hook) do |_target, opt, _|
          options = opt
        end

        redirect_pry_io(StringIO.new("exit"), StringIO.new) do
          Pry.start binding, hello: :baby
        end

        expect(options[:hello]).to eq :baby

        Pry.config.hooks.delete_hook(:when_started, :test_hook)
      end

      describe "target" do
        it 'should yield the target, as a binding ' do
          b = nil
          Pry.config.hooks.add_hook(:when_started, :test_hook) do |target, _opt, _|
            b = target
          end

          redirect_pry_io(StringIO.new("exit"), StringIO.new) do
            Pry.start 5, hello: :baby
          end

          expect(b.is_a?(Binding)).to eq true
          Pry.config.hooks.delete_hook(:when_started, :test_hook)
        end

        it 'should yield the target to the hook' do
          b = nil
          Pry.config.hooks.add_hook(:when_started, :test_hook) do |target, _opt, _|
            b = target
          end

          redirect_pry_io(StringIO.new("exit"), StringIO.new) do
            Pry.start 5, hello: :baby
          end

          expect(b.eval('self')).to eq 5
          Pry.config.hooks.delete_hook(:when_started, :test_hook)
        end
      end

      it 'should allow overriding of target (and binding_stack)' do
        o = Object.new
        class << o; attr_accessor :value; end

        Pry.config.hooks.add_hook(
          :when_started, :test_hook
        ) do |_target, _opt, pry_instance|
          pry_instance.binding_stack = [Pry.binding_for(o)]
        end

        redirect_pry_io(InputTester.new("@value = true", "exit-all")) do
          Pry.start binding, hello: :baby
        end

        expect(o.value).to eq true
        Pry.config.hooks.delete_hook(:when_started, :test_hook)
      end
    end

    describe "after_session hook" do
      it 'should always run, even if uncaught exception bubbles out of repl' do
        o = OpenStruct.new
        o.great_escape = Class.new(StandardError)

        old_ew = Pry.config.unrescued_exceptions
        Pry.config.unrescued_exceptions << o.great_escape

        array = [1, 2, 3, 4, 5]

        begin
          redirect_pry_io(StringIO.new("raise great_escape"), StringIO.new) do
            Pry.start(
              o,
              hooks: Pry::Hooks.new.add_hook(:after_session, :cleanup) { array = nil }
            )
          end
        rescue StandardError => ex
          exception = ex
        end

        # ensure that an exception really was raised and it broke out
        # of the repl
        expect(exception.is_a?(o.great_escape)).to eq true

        # check that after_session hook ran
        expect(array).to eq nil

        # cleanup after test
        Pry.config.unrescued_exceptions = old_ew
      end

      describe "before_eval hook" do
        describe "modifying input code" do
          it 'should replace input code with code determined by hook' do
            hooks = Pry::Hooks.new.add_hook(:before_eval, :quirk) do |code, _pry|
              code.replace(":little_duck")
            end
            redirect_pry_io(InputTester.new(":jemima", "exit-all"), out = StringIO.new) do
              Pry.start(self, hooks: hooks)
            end
            expect(out.string).to match(/little_duck/)
            expect(out.string).not_to match(/jemima/)
          end

          it 'should not interfere with command processing when replacing input code' do
            commands = Pry::CommandSet.new do
              import_from Pry::Commands, "exit-all"

              command "how-do-you-like-your-blue-eyed-boy-now-mister-death" do
                output.puts "in hours of bitterness i imagine balls of sapphire, of metal"
              end
            end

            hooks = Pry::Hooks.new.add_hook(:before_eval, :quirk) do |code, _pry|
              code.replace(":little_duck")
            end

            redirect_pry_io(
              InputTester.new(
                "how-do-you-like-your-blue-eyed-boy-now-mister-death", "exit-all"
              ),
              out = StringIO.new
            ) do
              Pry.start(self, hooks: hooks, commands: commands)
            end
            expect(out.string).to match(
              /in hours of bitterness i imagine balls of sapphire, of metal/
            )
            expect(out.string).not_to match(/little_duck/)
          end
        end
      end

      describe "exceptions" do
        before do
          Pry.config.hooks.add_hook(:after_eval, :baddums) { raise "Baddums" }
          Pry.config.hooks.add_hook(:after_eval, :simbads) { raise "Simbads" }
        end

        after do
          Pry.config.hooks.delete_hook(:after_eval, :baddums)
          Pry.config.hooks.delete_hook(:after_eval, :simbads)
        end
        it "should not raise exceptions" do
          expect { mock_pry("1", "2", "3") }.to_not raise_error
        end

        it "should print out a notice for each exception raised" do
          expect(mock_pry("1")).to match(
            /after_eval\shook\sfailed:\sRuntimeError:\sBaddums\n
            .*after_eval\shook\sfailed:\sRuntimeError:\sSimbads/xm
          )
        end
      end
    end
  end

  describe "anonymous hooks" do
    it 'should allow adding of hook without a name' do
      @hooks.add_hook(:test_hook, nil) {}
      expect(@hooks.hook_count(:test_hook)).to eq 1
    end

    it 'should only allow one anonymous hook to exist' do
      @hooks.add_hook(:test_hook, nil) {}
      @hooks.add_hook(:test_hook, nil) {}
      expect(@hooks.hook_count(:test_hook)).to eq 1
    end

    it 'should execute most recently added anonymous hook' do
      x = nil
      y = nil
      @hooks.add_hook(:test_hook, nil) { y = 1 }
      @hooks.add_hook(:test_hook, nil) { x = 2 }
      @hooks.exec_hook(:test_hook)
      expect(y).to eq nil
      expect(x).to eq 2
    end
  end
end
