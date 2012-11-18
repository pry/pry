require 'helper'

if !mri18_and_no_real_source_location?
  describe "show-source" do
    before do
      @str_output = StringIO.new
      @o = Object.new
      Object.const_set(:Test, Module.new)
    end

    after do
      Pad.clear
    end

    it "should output a method's source" do
      pry_eval('show-source sample_method').should =~ /def sample/
    end

    it "should output help" do
      pry_eval('show-source -h').should =~ /Usage: show-source/
    end

    it "should output a method's source with line numbers" do
      pry_eval('show-source -l sample_method').should =~ /\d+: def sample/
    end

    it "should output a method's source with line numbers starting at 1" do
      pry_eval('show-source -b sample_method').should =~ /1: def sample/
    end

    it "should output a method's source if inside method and no name given" do
      def @o.sample
        pry_eval(binding, 'show-source').should =~ /def @o.sample/
      end
      @o.sample
    end

    it "should output a method's source inside method using the -l switch" do
      def @o.sample
        pry_eval(binding, 'show-source -l').should =~ /def @o.sample/
      end
      @o.sample
    end

    it "should find methods even if there are spaces in the arguments" do
      def @o.foo(*bars)
        "Mr flibble"
        self
      end

      out = pry_eval(binding, "show-source @o.foo('bar', 'baz bam').foo")
      out.should =~ /Mr flibble/
    end

    it "should find methods even if the object overrides method method" do
      c = Class.new{
        def method;
          98
        end
      }

      pry_eval(binding, "show-source c.new.method").should =~ /98/
    end

    it "should not show the source when a non-extant method is requested" do
      c = Class.new{ def method; 98; end }
      mock_pry(binding, "show-source c#wrongmethod").should =~ /undefined method/
    end

    it "should find instance_methods if the class overrides instance_method" do
      c = Class.new{
        def method;
          98
        end

        def self.instance_method; 789; end
      }

      pry_eval(binding, "show-source c#method").should =~ /98/
    end

    it "should find instance methods with -M" do
      c = Class.new{ def moo; "ve over!"; end }

      pry_eval(binding, "cd c", "show-source -M moo").should =~ /ve over/
    end

    it "should not find instance methods with -m" do
      c = Class.new{ def moo; "ve over!"; end }

      proc {
        pry_eval(binding, 'cd c', 'show-source -m moo')
      }.should.raise(Pry::CommandError).message.should =~ /could not be found/
    end

    it "should find normal methods with -m" do
      c = Class.new{ def self.moo; "ve over!"; end }

      pry_eval(binding, 'cd c', 'show-source -m moo').should =~ /ve over/
    end

    it "should not find normal methods with -M" do
      c = Class.new{ def self.moo; "ve over!"; end }

      proc {
        pry_eval(binding, 'cd c', 'show-source -M moo')
      }.should.raise(Pry::CommandError).message.should =~ /could not be found/
    end

    it "should find normal methods with no -M or -m" do
      c = Class.new{ def self.moo; "ve over!"; end }

      pry_eval(binding, "cd c", "show-source moo").should =~ /ve over/
    end

    it "should find instance methods with no -M or -m" do
      c = Class.new{ def moo; "ve over!"; end }

      pry_eval(binding, "cd c", "show-source moo").should =~ /ve over/
    end

    it "should find super methods" do
      class Foo
        def foo(*bars)
          :super_wibble
        end
      end
      o = Foo.new
      Object.remove_const(:Foo)
      def o.foo(*bars)
        :wibble
      end

      pry_eval(binding, "show-source --super o.foo").
          should =~ /:super_wibble/
    end

    it "should raise a CommandError when super method doesn't exist" do
      def @o.foo(*bars); end

      proc {
        pry_eval(binding, "show-source --super @o.foo")
      }.should.raise(Pry::CommandError).message.should =~ /no super method/
    end

    # dynamically defined method source retrieval is only supported in
    # 1.9 - where Method#source_location is native
    if RUBY_VERSION =~ /1.9/
      it "should output the source of a method defined inside Pry" do
        out = pry_eval("def dyn_method\n:test\nend", 'show-source dyn_method')
        out.should =~ /def dyn_method/
        Object.remove_method :dyn_method
      end

      it 'should output source for an instance method defined inside pry' do
        pry_tester.tap do |t|
          t.eval "class Test::A\n  def yo\n  end\nend"
          t.eval('show-source Test::A#yo').should =~ /def yo/
        end
      end

      it 'should output source for a repl method defined using define_method' do
        pry_tester.tap do |t|
          t.eval "class Test::A\n  define_method(:yup) {}\nend"
          t.eval('show-source Test::A#yup').should =~ /define_method\(:yup\)/
        end
      end
    end

    describe "on sourcable objects" do
      if RUBY_VERSION =~ /1.9/
        it "should output source defined inside pry" do
          pry_tester.tap do |t|
            t.eval "hello = proc { puts 'hello world!' }"
            t.eval("show-source hello").should =~ /proc { puts/
          end
        end
      end

      it "should output source for procs/lambdas stored in variables" do
        hello = proc { puts 'hello world!' }
        pry_eval(binding, 'show-source hello').should =~ /proc { puts/
      end

      it "should output source for procs/lambdas stored in constants" do
        HELLO = proc { puts 'hello world!' }
        pry_eval(binding, "show-source HELLO").should =~ /proc { puts/
        Object.remove_const(:HELLO)
      end

      it "should output source for method objects" do
        def @o.hi; puts 'hi world'; end
        meth = @o.method(:hi)
        pry_eval(binding, "show-source meth").should =~ /puts 'hi world'/
      end

      describe "on variables that shadow methods" do
        before do
          @t = pry_tester.eval unindent(<<-EOS)
            class ::TestHost
              def hello
                hello = proc { ' smile ' }
                pry_tester(binding)
              end
            end
            ::TestHost.new.hello
          EOS
        end

        after do
          Object.remove_const(:TestHost)
        end

        it "source of variable should take precedence over method that is being shadowed" do
          source = @t.eval('show-source hello')
          source.should.not =~ /def hello/
          source.should =~ /proc { ' smile ' }/
        end

        it "source of method being shadowed should take precedence over variable
            if given self.meth_name syntax" do
          @t.eval('show-source self.hello').should =~ /def hello/
        end
      end

    end

    describe "on variable or constant" do
      before do
        class TestHost
          def hello
            "hi there"
          end
        end
      end

      after do
        Object.remove_const(:TestHost)
      end

      it "should output source of its class if variable doesn't respond to source_location" do
        test_host = TestHost.new
        pry_eval(binding, 'show-source test_host').
            should =~ /class TestHost\n.*def hello/
      end

      it "should output source of its class if constant doesn't respond to source_location" do
        TEST_HOST = TestHost.new
        pry_eval(binding, 'show-source TEST_HOST').
            should =~ /class TestHost\n.*def hello/
        Object.remove_const(:TEST_HOST)
      end
    end

    describe "on modules" do
      before do
        class ShowSourceTestSuperClass
          def alpha
          end
        end

        class ShowSourceTestClass<ShowSourceTestSuperClass
          def alpha
          end
        end

        module ShowSourceTestSuperModule
          def alpha
          end
        end

        module ShowSourceTestModule
          include ShowSourceTestSuperModule
          def alpha
          end
        end

        ShowSourceTestClassWeirdSyntax = Class.new do
          def beta
          end
        end

        ShowSourceTestModuleWeirdSyntax = Module.new do
          def beta
          end
        end
      end

      after do
        Object.remove_const :ShowSourceTestSuperClass
        Object.remove_const :ShowSourceTestClass
        Object.remove_const :ShowSourceTestClassWeirdSyntax
        Object.remove_const :ShowSourceTestSuperModule
        Object.remove_const :ShowSourceTestModule
        Object.remove_const :ShowSourceTestModuleWeirdSyntax
      end

      describe "basic functionality, should find top-level module definitions" do
        it 'should show source for a class' do
          pry_eval('show-source ShowSourceTestClass').
              should =~ /class ShowSourceTestClass.*?def alpha/m
        end

        it 'should show source for a super class' do
          pry_eval('show-source -s ShowSourceTestClass').
              should =~ /class ShowSourceTestSuperClass.*?def alpha/m
        end

        it 'should show source for a module' do
          pry_eval('show-source ShowSourceTestModule').
              should =~ /module ShowSourceTestModule/
        end

        it 'should show source for an ancestor module' do
          pry_eval('show-source -s ShowSourceTestModule').
              should =~ /module ShowSourceTestSuperModule/
        end

        it 'should show source for a class when Const = Class.new syntax is used' do
          pry_eval('show-source ShowSourceTestClassWeirdSyntax').
              should =~ /ShowSourceTestClassWeirdSyntax = Class.new/
        end

        it 'should show source for a super class when Const = Class.new syntax is used' do
          pry_eval('show-source -s ShowSourceTestClassWeirdSyntax').
              should =~ /class Object/
        end

        it 'should show source for a module when Const = Module.new syntax is used' do
          pry_eval('show-source ShowSourceTestModuleWeirdSyntax').
              should =~ /ShowSourceTestModuleWeirdSyntax = Module.new/
        end
      end

      if !Pry::Helpers::BaseHelpers.mri_18?
        before do
          pry_eval unindent(<<-EOS)
            class Dog
              def woof
              end
            end

            class TobinaMyDog < Dog
              def woof
              end
            end
          EOS
        end

        after do
          Object.remove_const :Dog
          Object.remove_const :TobinaMyDog
        end

        describe "in REPL" do
          it 'should find class defined in repl' do
            pry_eval('show-source TobinaMyDog').should =~ /class TobinaMyDog/
          end
          it 'should find superclass defined in repl' do
            pry_eval('show-source -s TobinaMyDog').should =~ /class Dog/
          end
        end
      end

      it 'should lookup module name with respect to current context' do
        constant_scope(:AlphaClass, :BetaClass) do
          class BetaClass
            def alpha
            end
          end

          class AlphaClass
            class BetaClass
              def beta
              end
            end
          end

          pry_eval(AlphaClass, 'show-source BetaClass').should =~ /def beta/
        end
      end

      it 'should lookup nested modules' do
        constant_scope(:AlphaClass) do
          class AlphaClass
            class BetaClass
              def beta
              end
            end
          end

          pry_eval('show-source AlphaClass::BetaClass').should =~ /class Beta/
        end
      end

      # note that pry assumes a class is only monkey-patched at most
      # ONCE per file, so will not find multiple monkeypatches in the
      # SAME file.
      describe "show-source -a" do
        it 'should show the source for all monkeypatches defined in different files' do
          class TestClassForShowSource
            def beta
            end
          end

          result = pry_eval('show-source TestClassForShowSource -a')
          result.should =~ /def alpha/
          result.should =~ /def beta/
        end

        it 'should show the source for a class_eval-based monkeypatch' do
          TestClassForShowSourceClassEval.class_eval do
            def class_eval_method
            end
          end

          result = pry_eval('show-source TestClassForShowSourceClassEval -a')
          result.should =~ /def class_eval_method/
        end

        it 'should show the source for an instance_eval-based monkeypatch' do
          TestClassForShowSourceInstanceEval.instance_eval do
            def instance_eval_method
            end
          end

          result = pry_eval('show-source TestClassForShowSourceInstanceEval -a')
          result.should =~ /def instance_eval_method/
        end
      end

      describe "when show-source is invoked without a method or class argument" do
        before do
          module TestHost
            class M
              def alpha; end
              def beta; end
            end

            module C
            end

            module D
              def self.invoked_in_method
                pry_eval(binding, 'show-source')
              end
            end
          end
        end

        after do
          Object.remove_const(:TestHost)
        end

        describe "inside a module" do
          it 'should display module source by default' do
            out = pry_eval(TestHost::M, 'show-source')
            out.should =~ /class M/
            out.should =~ /def alpha/
            out.should =~ /def beta/
          end

          it 'should be unable to find module source if no methods defined' do
            proc {
              pry_eval(TestHost::C, 'show-source')
            }.should.raise(Pry::CommandError).
              message.should =~ /Cannot find a definition for/
          end

          it 'should display method code (rather than class) if Pry started inside method binding' do
            out = TestHost::D.invoked_in_method
            out.should =~ /invoked_in_method/
            out.should.not =~ /module D/
          end

          it 'should display class source when inside instance' do
            out = pry_eval(TestHost::M.new, 'show-source')
            out.should =~ /class M/
            out.should =~ /def alpha/
            out.should =~ /def beta/
          end

          it 'should allow options to be passed' do
            out = pry_eval(TestHost::M, 'show-source -b')
            out.should =~ /\d:\s*class M/
            out.should =~ /\d:\s*def alpha/
            out.should =~ /\d:\s*def beta/
          end

           describe "should skip over broken modules" do
            before do
              module BabyDuck

                module Muesli
                  binding.eval("def a; end", "dummy.rb", 1)
                  binding.eval("def b; end", "dummy.rb", 2)
                  binding.eval("def c; end", "dummy.rb", 3)
                end

                module Muesli
                  def d; end
                  def e; end
                end
              end
            end

            after do
              Object.remove_const(:BabyDuck)
            end

            it 'should return source for first valid module' do
              out = pry_eval('show-source BabyDuck::Muesli')
              out.should =~ /def d; end/
              out.should.not =~ /def a; end/
            end

          end
        end
      end
    end

    describe "on commands" do
      before do
        @oldset = Pry.config.commands
        @set = Pry.config.commands = Pry::CommandSet.new do
          import Pry::Commands
        end
      end

      after do
        Pry.config.commands = @oldset
      end

      it 'should show source for an ordinary command' do
        @set.command "foo", :body_of_foo do; end

        pry_eval('show-source foo').should =~ /:body_of_foo/
      end

      it "should output source of commands using special characters" do
        @set.command "!", "Clear the input buffer" do; end

        pry_eval('show-source !').should =~ /Clear the input buffer/
      end

      it 'should show source for a command with spaces in its name' do
        @set.command "foo bar", :body_of_foo_bar do; end

        pry_eval('show-source "foo bar"').should =~ /:body_of_foo_bar/
      end

      it 'should show source for a command by listing name' do
        @set.command /foo(.*)/, :body_of_foo_bar_regex, :listing => "bar" do; end

        pry_eval('show-source bar').should =~ /:body_of_foo_bar_regex/
      end
    end
  end
end
