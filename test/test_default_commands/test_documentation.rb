require 'helper'

if !mri18_and_no_real_source_location?
  describe "Pry::DefaultCommands::Documentation" do
    describe "show-doc" do
      before do
        @str_output = StringIO.new
        @o = Object.new
      end

      it 'should output a method\'s documentation' do
        redirect_pry_io(InputTester.new("show-doc sample_method", "exit-all"), @str_output) do
          pry
        end

        @str_output.string.should =~ /sample doc/
      end

      it 'should output a method\'s documentation with line numbers' do
        redirect_pry_io(InputTester.new("show-doc sample_method -l", "exit-all"), @str_output) do
          pry
        end

        @str_output.string.should =~ /\d: sample doc/
      end

      it 'should output a method\'s documentation with line numbers (base one)' do
        redirect_pry_io(InputTester.new("show-doc sample_method -b", "exit-all"), @str_output) do
          pry
        end

        @str_output.string.should =~ /1: sample doc/
      end

      it 'should output a method\'s documentation if inside method without needing to use method name' do
        Pad.str_output = @str_output

        # sample comment
        def @o.sample
          redirect_pry_io(InputTester.new("show-doc", "exit-all"), Pad.str_output) do
            binding.pry
          end
        end
        @o.sample

        Pad.str_output.string.should =~ /sample comment/
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

        mock_pry(binding, "show-doc o.initialize").should =~ /instancey initialize/
        mock_pry(binding, "show-doc --super o.initialize").should =~ /grungy initialize/
        mock_pry(binding, "show-doc o.initialize -ss").should =~ /classy initialize/
        mock_pry(binding, "show-doc --super o.initialize -ss").should == mock_pry("show-doc Object#initialize")
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
          mock_pry(binding, "show-doc c#initialize").should =~ /c.new :foo/
          Pry.config.color = true
          # I don't want the test to rely on which colour codes are there, just to
          # assert that "something" is being colourized.
          mock_pry(binding, "show-doc c#initialize").should.not =~ /c.new :foo/
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
          mock_pry(binding, "show-doc c#initialize").should =~ /c.new\(:foo\)/
          Pry.config.color = true
          # I don't want the test to rely on which colour codes are there, just to
          # assert that "something" is being colourized.
          mock_pry(binding, "show-doc c#initialize").should.not =~ /c.new\(:foo\)/
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
          Pry.config.color = true
          mock_pry(binding, "show-doc c#decolumnize").should =~ /ls -l \$HOME/
          mock_pry(binding, "show-doc c#decolumnize").should.not =~ /`ls -l \$HOME`/
        ensure
          Pry.config.color = false
        end
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
          mock_pry("show-doc ShowSourceTestClass").should =~ /god this is boring1/
        end

        it 'should show docs for a module' do
          mock_pry("show-doc ShowSourceTestModule").should =~ /god this is boring2/
        end

        it 'should show docs for a class when Const = Class.new syntax is used' do
          mock_pry("show-doc ShowSourceTestClassWeirdSyntax").should =~ /god this is boring3/
        end

        it 'should show docs for a module when Const = Module.new syntax is used' do
          mock_pry("show-doc ShowSourceTestModuleWeirdSyntax").should =~ /god this is boring4/
        end
      end

      if !Pry::Helpers::BaseHelpers.mri_18?
        describe "in REPL" do
          it 'should find class defined in repl' do
            mock_pry("# hello tobina", "class TobinaMyDog", "def woof", "end", "end", "show-doc TobinaMyDog").should =~ /hello tobina/
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

          redirect_pry_io(InputTester.new("show-doc BetaClass", "exit-all"), outp=StringIO.new) do
            AlphaClass.pry
          end

          outp.string.should =~ /nested beta/
        end
      end

      it 'should lookup nested modules' do
        constant_scope(:AlphaClass) do
          class AlphaClass

            # nested beta
            class BetaClass
              def beta
              end
            end
          end

          mock_pry("show-doc AlphaClass::BetaClass").should =~ /nested beta/
        end
      end

      describe "show-doc -a" do
        it 'should show the docs for all monkeypatches defined in different files' do

          # local monkeypatch
          class TestClassForShowSource
            def beta
            end
          end

          result = mock_pry("show-doc TestClassForShowSource -a")
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
          redirect_pry_io(InputTester.new("show-doc"), out = StringIO.new) do
            Pry.start(TestHost::M)
          end

          out.string.should =~ /hello there froggy/
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
          redirect_pry_io(InputTester.new("show-doc TestHost::M"), out = StringIO.new) do
            Pry.start
          end

          out.string.should =~ /goodbye/
          out.string.should.not =~ /hello/
        end

      end
    end

  end
end
