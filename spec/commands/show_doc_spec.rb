require 'helper'

if !mri18_and_no_real_source_location?
  describe "show-doc" do
    before do
      @o = Object.new
    end

    it 'should output a method\'s documentation' do
      pry_eval("show-doc sample_method").should =~ /sample doc/
    end

    it 'should output a method\'s documentation with line numbers' do
      pry_eval("show-doc sample_method -l").should =~ /\d: sample doc/
    end

    it 'should output a method\'s documentation with line numbers (base one)' do
      pry_eval("show-doc sample_method -b").should =~ /1: sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      # sample comment
      def @o.sample
        pry_eval(binding, 'show-doc').should =~ /sample comment/
      end
      @o.sample
    end

    it "should be able to find super methods" do
      c = Class.new{
        # classy initialize!
        def initialize(*args); end
      }

      d = Class.new(c){
        # grungy initialize??
        def initialize(*args, &block); end
      }

      o = d.new

      # instancey initialize!
      def o.initialize; end

      t = pry_tester(binding)

      t.eval("show-doc o.initialize").should =~ /instancey initialize/
      t.eval("show-doc --super o.initialize").should =~ /grungy initialize/
      t.eval("show-doc o.initialize -ss").should =~ /classy initialize/

      begin
        require 'pry-doc'
        t.eval("show-doc --super o.initialize -ss").should ==
          t.eval("show-doc Object#initialize")
      rescue LoadError
      end
    end

    describe "rdoc highlighting" do
      it "should syntax highlight code in rdoc" do
        c = Class.new{
          # This can initialize your class:
          #
          #   a = c.new :foo
          #
          # @param foo
          def initialize(foo); end
        }

        begin
          t = pry_tester(binding)
          t.eval("show-doc c#initialize").should =~ /c.new :foo/
          Pry.config.color = true
          # I don't want the test to rely on which colour codes are there, just to
          # assert that "something" is being colourized.
          t.eval("show-doc c#initialize").should.not =~ /c.new :foo/
        ensure
          Pry.config.color = false
        end
      end

      it "should syntax highlight `code` in rdoc" do
        c = Class.new{
          # After initializing your class with `c.new(:foo)`, go have fun!
          #
          # @param foo
          def initialize(foo); end
        }

        begin
          t = pry_tester(binding)
          t.eval("show-doc c#initialize").should =~ /c.new\(:foo\)/
          Pry.config.color = true
          # I don't want the test to rely on which colour codes are there, just to
          # assert that "something" is being colourized.
          t.eval("show-doc c#initialize").should.not =~ /c.new\(:foo\)/
        ensure
          Pry.config.color = false
        end

      end

      it "should not syntax highlight `` inside code" do
        c = Class.new{
          # Convert aligned output (from many shell commands) into nested arrays:
          #
          #   a = decolumnize `ls -l $HOME`
          #
          # @param output
          def decolumnize(output); end
        }

        begin
          t = pry_tester(binding)
          Pry.config.color = true
          t.eval("show-doc c#decolumnize").should =~ /ls -l \$HOME/
          t.eval("show-doc c#decolumnize").should.not =~ /`ls -l \$HOME`/
        ensure
          Pry.config.color = false
        end
      end
    end

    describe "on sourcable objects" do
      it "should show documentation for object" do
        # this is a documentation
        hello = proc { puts 'hello world!' }
        mock_pry(binding, "show-doc hello").should =~ /this is a documentation/
      end
    end

    describe "on modules" do
      before do
        # god this is boring1
        class ShowSourceTestClass
          def alpha
          end
        end

        # god this is boring2
        module ShowSourceTestModule
          def alpha
          end
        end

        # god this is boring3
        ShowSourceTestClassWeirdSyntax = Class.new do
          def beta
          end
        end

        # god this is boring4
        ShowSourceTestModuleWeirdSyntax = Module.new do
          def beta
          end
        end
      end

      after do
        Object.remove_const :ShowSourceTestClass
        Object.remove_const :ShowSourceTestClassWeirdSyntax
        Object.remove_const :ShowSourceTestModule
        Object.remove_const :ShowSourceTestModuleWeirdSyntax
      end

      describe "basic functionality, should show docs for top-level module definitions" do
        it 'should show docs for a class' do
          pry_eval("show-doc ShowSourceTestClass").should =~
            /god this is boring1/
        end

        it 'should show docs for a module' do
          pry_eval("show-doc ShowSourceTestModule").should =~
            /god this is boring2/
        end

        it 'should show docs for a class when Const = Class.new syntax is used' do
          pry_eval("show-doc ShowSourceTestClassWeirdSyntax").should =~
            /god this is boring3/
        end

        it 'should show docs for a module when Const = Module.new syntax is used' do
          pry_eval("show-doc ShowSourceTestModuleWeirdSyntax").should =~
            /god this is boring4/
        end
      end

      if !Pry::Helpers::BaseHelpers.mri_18?
        describe "in REPL" do
          it 'should find class defined in repl' do
            t = pry_tester
            t.eval <<-RUBY
              # hello tobina
              class TobinaMyDog
                def woof
                end
              end
            RUBY
            t.eval('show-doc TobinaMyDog').should =~ /hello tobina/
            Object.remove_const :TobinaMyDog
          end
        end
      end

      it 'should lookup module name with respect to current context' do
        constant_scope(:AlphaClass, :BetaClass) do
          # top-level beta
          class BetaClass
            def alpha
            end
          end

          class AlphaClass
            # nested beta
            class BetaClass
              def beta
              end
            end
          end

          pry_eval(AlphaClass, "show-doc BetaClass").should =~ /nested beta/
        end
      end

      it 'should look up nested modules' do
        constant_scope(:AlphaClass) do
          class AlphaClass
            # nested beta
            class BetaClass
              def beta
              end
            end
          end

          pry_eval("show-doc AlphaClass::BetaClass").should =~
            /nested beta/
        end
      end

      describe "show-doc -a" do
        it 'should show the docs for all monkeypatches defined in different files' do
          # local monkeypatch
          class TestClassForShowSource
            def beta
            end
          end

          result = pry_eval("show-doc TestClassForShowSource -a")
          result.should =~ /used by/
          result.should =~ /local monkeypatch/
        end
      end

      describe "when no class/module arg is given" do
        before do
          module TestHost

            # hello there froggy
            module M
              def d; end
              def e; end
            end
          end
        end

        after do
          Object.remove_const(:TestHost)
        end

        it 'should return doc for current module' do
          pry_eval(TestHost::M, "show-doc").should =~ /hello there froggy/
        end
      end

      describe "should skip over broken modules" do
        before do
          module TestHost
            # hello
            module M
              binding.eval("def a; end", "dummy.rb", 1)
              binding.eval("def b; end", "dummy.rb", 2)
              binding.eval("def c; end", "dummy.rb", 3)
            end

            # goodbye
            module M
              def d; end
              def e; end
            end
          end
        end

        after do
          Object.remove_const(:TestHost)
        end

        it 'should return doc for first valid module' do
          result = pry_eval("show-doc TestHost::M")
          result.should =~ /goodbye/
          result.should.not =~ /hello/
        end
      end
    end

    describe "on commands" do
      # mostly copied & modified from test_help.rb
      before do
        @oldset = Pry.config.commands
        @set = Pry.config.commands = Pry::CommandSet.new do
          import Pry::Commands
        end
      end

      after do
        Pry.config.commands = @oldset
      end

      it 'should display help for a specific command' do
        pry_eval('show-doc ls').should =~ /Usage: ls/
      end

      it 'should display help for a regex command with a "listing"' do
        @set.command /bar(.*)/, "Test listing", :listing => "foo" do; end
        pry_eval('show-doc foo').should =~ /Test listing/
      end

      it 'should display help for a command with a spaces in its name' do
        @set.command "command with spaces", "description of a command with spaces" do; end
        pry_eval('show-doc "command with spaces"').should =~ /description of a command with spaces/
      end
    end
  end
end
