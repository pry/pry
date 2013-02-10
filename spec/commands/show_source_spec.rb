require 'helper'
require "fixtures/show_source_doc_examples"

if !PryTestHelpers.mri18_and_no_real_source_location?
  describe "show-source" do
    before do
      @o = Object.new
      def @o.sample_method
        :sample
      end

      Object.const_set(:Test, Module.new)
    end

    after do
      Pad.clear
    end

    it "should output a method's source" do
      pry_eval(binding, 'show-source @o.sample_method').should =~ /def @o.sample/
    end

    it "should output help" do
      pry_eval('show-source -h').should =~ /Usage:\s+show-source/
    end

    it "should output a method's source with line numbers" do
      pry_eval(binding, 'show-source -l @o.sample_method').should =~ /\d+: def @o.sample/
    end

    it "should output a method's source with line numbers starting at 1" do
      pry_eval(binding, 'show-source -b @o.sample_method').should =~ /1: def @o.sample/
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
      mock_pry(binding, "show-source c#wrongmethod").should =~ /Couldn't locate/
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

    it "should find instance methods with self#moo" do
      c = Class.new{ def moo; "ve over!"; end }

      pry_eval(binding, "cd c", "show-source self#moo").should =~ /ve over/
    end

    it "should not find instance methods with self.moo" do
      c = Class.new{ def moo; "ve over!"; end }

      proc {
        pry_eval(binding, 'cd c', 'show-source self.moo')
      }.should.raise(Pry::CommandError).message.should =~ /Couldn't locate/
    end

    it "should find normal methods with self.moo" do
      c = Class.new{ def self.moo; "ve over!"; end }

      pry_eval(binding, 'cd c', 'show-source self.moo').should =~ /ve over/
    end

    it "should not find normal methods with self#moo" do
      c = Class.new{ def self.moo; "ve over!"; end }

      proc {
        pry_eval(binding, 'cd c', 'show-source self#moo')
      }.should.raise(Pry::CommandError).message.should =~ /Couldn't locate/
    end

    it "should find normal methods (i.e non-instance methods) by default" do
      c = Class.new{ def self.moo; "ve over!"; end }

      pry_eval(binding, "cd c", "show-source moo").should =~ /ve over/
    end

    it "should find instance methods if no normal methods available" do
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
      }.should.raise(Pry::CommandError).message.should =~ /No superclass found/
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

      it "should output the source of a command defined inside Pry" do
        command_definition = %{
          Pry.commands.command "hubba-hubba" do
            puts "that's what she said!"
          end
        }
        out = pry_eval(command_definition, 'show-source hubba-hubba')
        out.should =~ /what she said/
        Pry.commands.delete "hubba-hubba"
      end
    end

    describe "on sourcable objects" do
      if RUBY_VERSION =~ /1.9/
        it "should output source defined inside pry" do
          pry_tester.tap do |t|
            t.eval "hello = proc { puts 'hello world!' }"
            t.eval("show-source hello").should =~ /proc \{ puts/
          end
        end
      end

      it "should output source for procs/lambdas stored in variables" do
        hello = proc { puts 'hello world!' }
        pry_eval(binding, 'show-source hello').should =~ /proc \{ puts/
      end

      it "should output source for procs/lambdas stored in constants" do
        HELLO = proc { puts 'hello world!' }
        pry_eval(binding, "show-source HELLO").should =~ /proc \{ puts/
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
            source.should =~ /proc \{ ' smile ' \}/
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

          it 'should ignore -a when object is not a module' do
            TestClassForShowSourceClassEval.class_eval do
              def class_eval_method
                :bing
              end
            end

            result = pry_eval('show-source TestClassForShowSourceClassEval#class_eval_method -a')
            result.should =~ /bing/
          end

          it 'should show the source for an instance_eval-based monkeypatch' do
            TestClassForShowSourceInstanceEval.instance_eval do
              def instance_eval_method
              end
            end

            result = pry_eval('show-source TestClassForShowSourceInstanceEval -a')
            result.should =~ /def instance_eval_method/
          end

          describe "messages relating to -a" do
            it 'indicates all available monkeypatches can be shown with -a when (when -a not used and more than one candidate exists for class)' do
              class TestClassForShowSource
                def beta
                end
              end

              result = pry_eval('show-source TestClassForShowSource')
              result.should =~ /available monkeypatches/
            end

            it 'shouldnt say anything about monkeypatches when only one candidate exists for selected class' do
              class Aarrrrrghh
                def o;end
              end

              result = pry_eval('show-source Aarrrrrghh')
              result.should.not =~ /available monkeypatches/
              Object.remove_const(:Aarrrrrghh)
            end
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
                message.should =~ /Couldn't locate/
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

        describe "block commands" do
          it 'should show source for an ordinary command' do
            @set.command "foo", :body_of_foo do; end

            pry_eval('show-source foo').should =~ /:body_of_foo/
          end

          it "should output source of commands using special characters" do
            @set.command "!%$", "I gots the yellow fever" do; end

            pry_eval('show-source !%$').should =~ /yellow fever/
          end

          it 'should show source for a command with spaces in its name' do
            @set.command "foo bar", :body_of_foo_bar do; end

            pry_eval('show-source foo bar').should =~ /:body_of_foo_bar/
          end

          it 'should show source for a command by listing name' do
            @set.command /foo(.*)/, :body_of_foo_bar_regex, :listing => "bar" do; end

            pry_eval('show-source bar').should =~ /:body_of_foo_bar_regex/
          end
        end

        describe "create_command commands" do
          it 'should show source for a command' do
            @set.create_command "foo", "babble" do
              def process() :body_of_foo end
            end
            pry_eval('show-source foo').should =~ /:body_of_foo/
          end

          it 'should show source for a command defined inside pry' do
            pry_eval %{
            _pry_.commands.create_command "foo", "babble" do
              def process() :body_of_foo end
            end
          }
          pry_eval('show-source foo').should =~ /:body_of_foo/
        end
      end

      describe "real class-based commands" do
        before do
          class ::TemporaryCommand < Pry::ClassCommand
            match 'temp-command'
            def process() :body_of_temp end
          end

          Pry.commands.add_command(::TemporaryCommand)
        end

        after do
          Object.remove_const(:TemporaryCommand)
        end

        it 'should show source for a command' do
          pry_eval('show-source temp-command').should =~ /:body_of_temp/
        end

        it 'should show source for a command defined inside pry' do
          pry_eval %{
            class ::TemporaryCommandInPry < Pry::ClassCommand
              match 'temp-command-in-pry'
              def process() :body_of_temp end
            end
          }
          Pry.commands.add_command(::TemporaryCommandInPry)
          pry_eval('show-source temp-command-in-pry').should =~ /:body_of_temp/
          Object.remove_const(:TemporaryCommandInPry)
        end
      end
    end

    describe "should set _file_ and _dir_" do
      it 'should set _file_ and _dir_ to file containing method source' do
        t = pry_tester
        t.process_command "show-source TestClassForShowSource#alpha"
        t.pry.last_file.should =~ /show_source_doc_examples/
        t.pry.last_dir.should =~ /fixtures/
      end
    end

    unless Pry::Helpers::BaseHelpers.rbx?
      describe "can't find class/module code" do
        describe "for classes" do
          before do
            module Jesus
              module Pig
                def lillybing; :lillybing; end
              end

              class Brian; end
              class Jingle
                def a; :doink; end
              end

              class Jangle < Jingle; include Pig; end
              class Bangle < Jangle; end
            end
          end

          after do
            Object.remove_const(:Jesus)
          end

          it 'shows superclass code' do
            t = pry_tester
            t.process_command "show-source Jesus::Jangle"
            t.last_output.should =~ /doink/
          end

          it 'ignores included modules' do
            t = pry_tester
            t.process_command "show-source Jesus::Jangle"
            t.last_output.should.not =~ /lillybing/
          end

          it 'errors when class has no superclass to show' do
            t = pry_tester
            lambda { t.process_command "show-source Jesus::Brian" }.should.raise(Pry::CommandError).message.
              should =~ /Couldn't locate/
          end

          it 'shows warning when reverting to superclass code' do
            t = pry_tester
            t.process_command "show-source Jesus::Jangle"
            t.last_output.should =~ /Warning.*?Cannot find.*?Jesus::Jangle.*Showing.*Jesus::Jingle instead/
          end

          it 'shows nth level superclass code (when no intermediary superclasses have code either)' do
            t = pry_tester
            t.process_command "show-source Jesus::Bangle"
            t.last_output.should =~ /doink/
          end

          it 'shows correct warning when reverting to nth level superclass' do
            t = pry_tester
            t.process_command "show-source Jesus::Bangle"
            t.last_output.should =~ /Warning.*?Cannot find.*?Jesus::Bangle.*Showing.*Jesus::Jingle instead/
          end
        end

        describe "for modules" do
          before do
            module Jesus
              module Alpha
                def alpha; :alpha; end
              end

              module Zeta; end

              module Beta
                include Alpha
              end

              module Gamma
                include Beta
              end
            end
          end

          after do
            Object.remove_const(:Jesus)
          end

          it 'shows included module code' do
            t = pry_tester
            t.process_command "show-source Jesus::Beta"
            t.last_output.should =~ /alpha/
          end

          it 'shows warning when reverting to included module code' do
            t = pry_tester
            t.process_command "show-source Jesus::Beta"
            t.last_output.should =~ /Warning.*?Cannot find.*?Jesus::Beta.*Showing.*Jesus::Alpha instead/
          end

          it 'errors when module has no included module to show' do
            t = pry_tester
            lambda { t.process_command "show-source Jesus::Zeta" }.should.raise(Pry::CommandError).message.
              should =~ /Couldn't locate/
          end

          it 'shows nth level included module code (when no intermediary modules have code either)' do
            t = pry_tester
            t.process_command "show-source Jesus::Gamma"
            t.last_output.should =~ /alpha/
          end

          it 'shows correct warning when reverting to nth level included module' do
            t = pry_tester
            t.process_command "show-source Jesus::Gamma"
            t.last_output.should =~ /Warning.*?Cannot find.*?Jesus::Gamma.*Showing.*Jesus::Alpha instead/
          end
        end
      end
    end
  end
end
