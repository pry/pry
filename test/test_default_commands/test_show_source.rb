require 'helper'

if !mri18_and_no_real_source_location?
  describe "show-source" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-source sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output help' do
      mock_pry('show-source -h').should =~ /Usage: show-source/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-source -l sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source with line numbers starting at 1' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-source -b sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /1: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-source", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /def o.sample/
      $str_output = nil
    end

    it 'should output a method\'s source if inside method without needing to use method name, and using the -l switch' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-source -l", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /\d+: def o.sample/
      $str_output = nil
    end

    it "should find methods even if there are spaces in the arguments" do
      o = Object.new
      def o.foo(*bars);
        "Mr flibble"
        self;
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-source o.foo('bar', 'baz bam').foo", "exit-all"), str_output) do
        binding.pry
      end
      str_output.string.should =~ /Mr flibble/
    end

    it "should find methods even if the object has an overridden method method" do
      c = Class.new{
        def method;
          98
        end
      }

      mock_pry(binding, "show-source c.new.method").should =~ /98/
    end

    it "should find instance_methods even if the class has an override instance_method method" do
      c = Class.new{
        def method;
          98
        end

        def self.instance_method; 789; end
      }

      mock_pry(binding, "show-source c#method").should =~ /98/
    end

    it "should find instance methods with -M" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c","show-source -M moo").should =~ /ve over/
    end

    it "should not find instance methods with -m" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-source -m moo").should =~ /could not be found/
    end

    it "should find normal methods with -m" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-source -m moo").should =~ /ve over/
    end

    it "should not find normal methods with -M" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-source -M moo").should =~ /could not be found/
    end

    it "should find normal methods with no -M or -m" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-source moo").should =~ /ve over/
    end

    it "should find instance methods with no -M or -m" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-source moo").should =~ /ve over/
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

      mock_pry(binding, "show-source --super o.foo").should =~ /:super_wibble/
    end

    it "should not raise an exception when a non-extant super method is requested" do
      o = Object.new
      def o.foo(*bars); end

      mock_pry(binding, "show-source --super o.foo").should =~ /'self.foo' has no super method/
    end

    # dynamically defined method source retrieval is only supported in
    # 1.9 - where Method#source_location is native
    if RUBY_VERSION =~ /1.9/
      it 'should output a method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("def dyna_method", ":testing", "end", "show-source dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output a method\'s source for a method defined inside pry, even if exceptions raised before hand' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("bad code", "123", "bad code 2", "1 + 2", "def dyna_method", ":testing", "end", "show-source dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output an instance method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        Object.remove_const :A if defined?(A)
        redirect_pry_io(InputTester.new("class A", "def yo", "end", "end", "show-source A#yo"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def yo/
        Object.remove_const :A
      end

      it 'should output an instance method\'s source for a method defined inside pry using define_method' do
        str_output = StringIO.new
        Object.remove_const :A if defined?(A)
        redirect_pry_io(InputTester.new("class A", "define_method(:yup) {}", "end", "show-source A#yup"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /define_method\(:yup\)/
        Object.remove_const :A
      end
    end

    describe "on modules" do
      before do
        class ShowSourceTestClass
          def alpha
          end
        end

        module ShowSourceTestModule
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
        Object.remove_const :ShowSourceTestClass
        Object.remove_const :ShowSourceTestClassWeirdSyntax
        Object.remove_const :ShowSourceTestModule
        Object.remove_const :ShowSourceTestModuleWeirdSyntax
      end

      describe "basic functionality, should find top-level module definitions" do
        it 'should show source for a class' do
          mock_pry("show-source ShowSourceTestClass").should =~ /class ShowSourceTest.*?def alpha/m
        end

        it 'should show source for a module' do
          mock_pry("show-source ShowSourceTestModule").should =~ /module ShowSourceTestModule/
        end

        it 'should show source for a class when Const = Class.new syntax is used' do
          mock_pry("show-source ShowSourceTestClassWeirdSyntax").should =~ /ShowSourceTestClassWeirdSyntax = Class.new/
        end

        it 'should show source for a module when Const = Module.new syntax is used' do
          mock_pry("show-source ShowSourceTestModuleWeirdSyntax").should =~ /ShowSourceTestModuleWeirdSyntax = Module.new/
        end
      end

      if !Pry::Helpers::BaseHelpers.mri_18?
        describe "in REPL" do
          it 'should find class defined in repl' do
            mock_pry("class TobinaMyDog", "def woof", "end", "end", "show-source TobinaMyDog").should =~ /class TobinaMyDog/
            Object.remove_const :TobinaMyDog
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

          redirect_pry_io(InputTester.new("show-source BetaClass", "exit-all"), out=StringIO.new) do
            AlphaClass.pry
          end

          out.string.should =~ /def beta/
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

          mock_pry("show-source AlphaClass::BetaClass").should =~ /class BetaClass/
        end
      end

      describe "show-source -a" do
        it 'should show the source for all monkeypatches defined in different files' do
          class TestClassForShowSource
            def beta
            end
          end

          result = mock_pry("show-source TestClassForShowSource -a")
          result.should =~ /def alpha/
          result.should =~ /def beta/
        end
      end
    end
  end
end
