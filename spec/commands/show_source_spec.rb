# frozen_string_literal: true

describe "show-source" do # rubocop:disable Metrics/BlockLength
  def define_persistent_class(file, class_body)
    file.puts(class_body)
    file.close
    require(file.path)
  end

  before do
    @o = Object.new
    def @o.sample_method
      :sample
    end
    Object.remove_const :Test if Object.const_defined? :Test
    Object.const_set(:Test, Module.new)
  end

  after do
    Pad.clear
  end

  it "should output a method's source" do
    expect(pry_eval(binding, 'show-source @o.sample_method')).to match(/def @o.sample/)
  end

  it "should output help" do
    expect(pry_eval('show-source -h')).to match(/Usage:\s+show-source/)
  end

  it "should output a method's source with line numbers" do
    expect(pry_eval(binding, 'show-source -l @o.sample_method'))
      .to match(/\d+: def @o.sample/)
  end

  it "should output a method's source with line numbers starting at 1" do
    expect(pry_eval(binding, 'show-source -b @o.sample_method'))
      .to match(/1: def @o.sample/)
  end

  it "should output a method's source if inside method and no name given" do
    def @o.sample
      pry_eval(binding, 'show-source')
    end
    docs = @o.sample
    expect(docs).to match(/def @o.sample/)
  end

  it "should output a method's source inside method using the -l switch" do
    def @o.sample
      pry_eval(binding, 'show-source -l')
    end
    docs = @o.sample
    expect(docs).to match(/def @o.sample/)
  end

  it "should find methods even if there are spaces in the arguments" do
    def @o.foo(*_bars)
      @foo = "Mr flibble"
      self
    end

    out = pry_eval(binding, "show-source @o.foo('bar', 'baz bam').foo")
    expect(out).to match(/Mr flibble/)
  end

  it "should find methods even if the object overrides method method" do
    _c = Class.new do
      def method
        98
      end
    end

    expect(pry_eval(binding, "show-source _c.new.method")).to match(/98/)
  end

  it "should not show the source when a non-extant method is requested" do
    _c = Class.new do
      def method
        98
      end
    end
    expect(mock_pry(binding, "show-source _c#wrongmethod"))
      .to match(/Couldn't locate/)
  end

  it "doesn't show the source and deliver an error message without exclamation point" do
    _c = Class.new
    error_message = "Error: Couldn't locate a definition for _c#wrongmethod\n"
    expect(mock_pry(binding, "show-source _c#wrongmethod")).to eq(error_message)
  end

  it "should find instance_methods if the class overrides instance_method" do
    _c = Class.new do
      def method
        98
      end

      def self.instance_method
        789
      end
    end

    expect(pry_eval(binding, "show-source _c#method")).to match(/98/)
  end

  it "should find instance methods with self#moo" do
    _c = Class.new do
      def moo
        "ve over!"
      end
    end

    expect(pry_eval(binding, "cd _c", "show-source self#moo")).to match(/ve over/)
  end

  it "should not find instance methods with self.moo" do
    _c = Class.new do
      def moo
        "ve over!"
      end
    end

    expect { pry_eval(binding, 'cd _c', 'show-source self.moo') }
      .to raise_error(Pry::CommandError, /Couldn't locate/)
  end

  it "should find normal methods with self.moo" do
    _c = Class.new do
      def self.moo
        "ve over!"
      end
    end

    expect(pry_eval(binding, 'cd _c', 'show-source self.moo')).to match(/ve over/)
  end

  it "should not find normal methods with self#moo" do
    _c = Class.new do
      def self.moo
        "ve over!"
      end
    end

    expect { pry_eval(binding, 'cd _c', 'show-source self#moo') }
      .to raise_error(Pry::CommandError, /Couldn't locate/)
  end

  it "should find normal methods (i.e non-instance methods) by default" do
    _c = Class.new do
      def self.moo
        "ve over!"
      end
    end

    expect(pry_eval(binding, "cd _c", "show-source moo")).to match(/ve over/)
  end

  it "should find instance methods if no normal methods available" do
    _c = Class.new do
      def moo
        "ve over!"
      end
    end

    expect(pry_eval(binding, "cd _c", "show-source moo")).to match(/ve over/)
  end

  describe "with -e option" do
    before do
      class FooBar
        def bar
          :bar
        end
      end
    end

    after do
      Object.remove_const(:FooBar)
    end

    it "shows the source code for the returned value as Ruby" do
      ReplTester.start target: binding do
        input 'show-source -e FooBar.new'
        output(/class FooBar/)
      end
    end
  end

  it "should raise a CommandError when super method doesn't exist" do
    def @o.foo(*bars); end

    expect { pry_eval(binding, "show-source --super @o.foo") }
      .to raise_error(Pry::CommandError, /No superclass found/)
  end

  it "should output the source of a method defined inside Pry" do
    out = pry_eval("def dyn_method\n:test\nend", 'show-source dyn_method')
    expect(out).to match(/def dyn_method/)
    Object.remove_method :dyn_method
  end

  it 'should output source for an instance method defined inside pry' do
    pry_tester.tap do |t|
      t.eval "class Test::A\n  def yo\n  end\nend"
      expect(t.eval('show-source Test::A#yo')).to match(/def yo/)
    end
  end

  it 'should output source for a repl method defined using define_method' do
    pry_tester.tap do |t|
      t.eval "class Test::A\n  define_method(:yup) {}\nend"
      expect(t.eval('show-source Test::A#yup')).to match(/define_method\(:yup\)/)
    end
  end

  it "should output the source of a command defined inside Pry" do
    command_definition = %(
      Pry.config.commands.command "hubba-hubba" do
        puts "that's what she said!"
      end
    )
    out = pry_eval(command_definition, 'show-source hubba-hubba')
    expect(out).to match(/what she said/)
    Pry.config.commands.delete "hubba-hubba"
  end

  context "when there's no source code but the comment exists" do
    before do
      class Foo
        # Bingo.
        def bar; end
      end

      allow_any_instance_of(Pry::Method).to receive(:source).and_return(nil)
    end

    after do
      Object.remove_const(:Foo)
    end

    it "outputs zero line numbers" do
      out = pry_eval('show-source Foo#bar')
      expect(out).to match(/
        Owner:\sFoo
        .+
        Number\sof\slines:\s0
        .+
        \*\*\sWarning:\sCannot\sfind\scode\sfor\s'bar'\s\(source_location\sis\snil\)
      /mx)
    end
  end

  describe "finding super methods with help of `--super` switch" do
    before do
      class Foo
        def foo(*_bars)
          :super_wibble
        end
      end
    end

    after do
      Object.remove_const(:Foo)
    end

    it "finds super methods with explicit method argument" do
      o = Foo.new
      def o.foo(*_bars)
        :wibble
      end

      expect(pry_eval(binding, "show-source --super o.foo")).to match(/:super_wibble/)
    end

    it "finds super methods without explicit method argument" do
      o = Foo.new
      def o.foo(*bars)
        @foo = :wibble
        pry_eval(binding, 'show-source --super')
      end

      expect(o.foo).to match(/:super_wibble/)
    end

    it "finds super methods with multiple --super " do
      o = Foo.new

      o.extend(
        Module.new do
          def foo
            :nibble
          end
        end
      )

      def o.foo(*bars)
        @foo = :wibble
        pry_eval(binding, 'show-source --super --super')
      end

      expect(o.foo).to match(/:super_wibble/)
    end
  end

  describe "on sourcable objects" do
    it "should output source defined inside pry" do
      pry_tester.tap do |t|
        t.eval "hello = proc { puts 'hello world!' }"
        expect(t.eval("show-source hello")).to match(/proc \{ puts/)
      end
    end

    it "should output source for procs/lambdas stored in variables" do
      _hello = proc { puts 'hello world!' }
      expect(pry_eval(binding, 'show-source _hello')).to match(/proc \{ puts/)
    end

    it "should output source for procs/lambdas stored in constants" do
      HELLO = proc { puts 'hello world!' }
      expect(pry_eval(binding, "show-source HELLO")).to match(/proc \{ puts/)
      Object.remove_const(:HELLO)
    end

    it "should output source for method objects" do
      def @o.hi
        puts 'hi world'
      end
      _meth = @o.method(:hi)
      expect(pry_eval(binding, "show-source _meth")).to match(/puts 'hi world'/)
    end

    describe "on variables that shadow methods" do
      before do
        @t = pry_tester.eval(unindent(<<-SHADOWED_VAR))
          class ::TestHost
            def hello
              hello = proc { ' smile ' }
              _foo = hello
              pry_tester(binding)
            end
          end
          ::TestHost.new.hello
        SHADOWED_VAR
      end

      after { Object.remove_const(:TestHost) }

      it "source of variable takes precedence over method that is being shadowed" do
        source = @t.eval('show-source hello')
        expect(source).not_to match(/def hello/)
        expect(source).to match(/proc \{ ' smile ' \}/)
      end

      it "source of method being shadowed should take precedence over variable
          if given self.meth_name syntax" do
        expect(@t.eval('show-source self.hello')).to match(/def hello/)
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

    after { Object.remove_const(:TestHost) }

    it "outputs source of its class if variable doesn't respond to source_location" do
      _test_host = TestHost.new
      expect(pry_eval(binding, 'show-source _test_host'))
        .to match(/class TestHost\n.*def hello/)
    end

    it "outputs source of its class if constant doesn't respond to source_location" do
      TEST_HOST = TestHost.new
      expect(pry_eval(binding, 'show-source TEST_HOST'))
        .to match(/class TestHost\n.*def hello/)
      Object.remove_const(:TEST_HOST)
    end
  end

  describe "on modules" do
    before do
      class ShowSourceTestSuperClass
        def alpha; end
      end

      class ShowSourceTestClass < ShowSourceTestSuperClass
        def alpha; end
      end

      module ShowSourceTestSuperModule
        def alpha; end
      end

      module ShowSourceTestModule
        include ShowSourceTestSuperModule
        def alpha; end
      end

      ShowSourceTestClassWeirdSyntax = Class.new do
        def beta; end
      end

      ShowSourceTestModuleWeirdSyntax = Module.new do
        def beta; end
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
        expect(pry_eval('show-source ShowSourceTestClass'))
          .to match(/class ShowSourceTestClass.*?def alpha/m)
      end

      it 'should show source for a super class' do
        expect(pry_eval('show-source -s ShowSourceTestClass'))
          .to match(/class ShowSourceTestSuperClass.*?def alpha/m)
      end

      it 'should show source for a module' do
        expect(pry_eval('show-source ShowSourceTestModule'))
          .to match(/module ShowSourceTestModule/)
      end

      it 'should show source for an ancestor module' do
        expect(pry_eval('show-source -s ShowSourceTestModule'))
          .to match(/module ShowSourceTestSuperModule/)
      end

      it 'should show source for a class when Const = Class.new syntax is used' do
        expect(pry_eval('show-source ShowSourceTestClassWeirdSyntax'))
          .to match(/ShowSourceTestClassWeirdSyntax = Class.new/)
      end

      it 'should show source for a super class when Const = Class.new syntax is used' do
        expect(pry_eval('show-source -s ShowSourceTestClassWeirdSyntax'))
          .to match(/class Object/)
      end

      it 'should show source for a module when Const = Module.new syntax is used' do
        expect(pry_eval('show-source ShowSourceTestModuleWeirdSyntax'))
          .to match(/ShowSourceTestModuleWeirdSyntax = Module.new/)
      end
    end

    before do
      pry_eval(unindent(<<-CLASSES))
        class Dog
          def woof
          end
        end

        class TobinaMyDog < Dog
          def woof
          end
        end
      CLASSES
    end

    after do
      Object.remove_const :Dog
      Object.remove_const :TobinaMyDog
    end

    describe "in REPL" do
      it 'should find class defined in repl' do
        expect(pry_eval('show-source TobinaMyDog')).to match(/class TobinaMyDog/)
      end

      it 'should find superclass defined in repl' do
        expect(pry_eval('show-source -s TobinaMyDog')).to match(/class Dog/)
      end
    end

    it 'should lookup module name with respect to current context' do
      temporary_constants(:AlphaClass, :BetaClass) do
        class BetaClass
          def alpha; end
        end

        class AlphaClass
          class BetaClass
            def beta; end
          end
        end

        expect(pry_eval(AlphaClass, 'show-source BetaClass')).to match(/def beta/)
      end
    end

    it 'should lookup nested modules' do
      temporary_constants(:AlphaClass) do
        class AlphaClass
          class BetaClass
            def beta; end
          end
        end

        expect(pry_eval('show-source AlphaClass::BetaClass')).to match(/class Beta/)
      end
    end

    # note that pry assumes a class is only monkey-patched at most
    # ONCE per file, so will not find multiple monkeypatches in the
    # SAME file.
    describe "show-source -a" do
      let(:tempfile) { Tempfile.new(%w[pry .rb]) }

      context "when there are instance method monkeypatches in different files" do
        before do
          define_persistent_class(tempfile, <<-CLASS)
            class TestClass
              def alpha; end
            end
          CLASS

          class TestClass
            def beta; end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "shows the source for all monkeypatches" do
          result = pry_eval('show-source TestClass -a')
          expect(result).to match(/def alpha/)
          expect(result).to match(/def beta/)
        end
      end

      context "when there are class method monkeypatches in different files" do
        before do
          define_persistent_class(tempfile, <<-CLASS)
            class TestClass
              def self.alpha; end
            end
          CLASS

          class TestClass
            def self.beta; end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "shows the source for all monkeypatches" do
          result = pry_eval('show-source TestClass -a')
          expect(result).to match(/def self.alpha/)
          expect(result).to match(/def self.beta/)
        end
      end

      context "when there are class-eval monkeypatches in different files" do
        let(:tempfile) { Tempfile.new(%w[pry .rb]) }

        before do
          define_persistent_class(tempfile, <<-CLASS)
            class TestClass
              def self.alpha; end
            end
          CLASS

          TestClass.class_eval do
            def class_eval_method
              :bing
            end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "shows the source for all monkeypatches" do
          result = pry_eval('show-source TestClass -a')
          expect(result).to match(/def class_eval_method/)
        end

        it "ignores -a because object is not a module" do
          result = pry_eval('show-source TestClass#class_eval_method -a')
          expect(result).to match(/bing/)
        end
      end

      context "when there are instance-eval monkeypatches in different files" do
        let(:tempfile) { Tempfile.new(%w[pry .rb]) }

        before do
          define_persistent_class(tempfile, <<-CLASS)
            class TestClass
              def self.alpha; end
            end
          CLASS

          TestClass.instance_eval do
            def instance_eval_method
              :bing
            end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "shows the source for all monkeypatches" do
          result = pry_eval('show-source TestClass -a')
          expect(result).to match(/def instance_eval_method/)
        end
      end

      context "when -a is not used and there are multiple monkeypatches" do
        let(:tempfile) { Tempfile.new(%w[pry .rb]) }

        before do
          define_persistent_class(tempfile, <<-CLASS)
            class TestClass
              def self.alpha; end
            end
          CLASS

          class TestClass
            def beta; end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "mentions available monkeypatches" do
          result = pry_eval('show-source TestClass')
          expect(result).to match(/available monkeypatches/)
        end
      end

      context "when -a is not used and there's only one candidate for the class" do
        before do
          # alpha
          class TestClass
            def alpha; end
          end
        end

        after do
          Object.remove_const(:TestClass)
        end

        it "doesn't mention anything about monkeypatches" do
          result = pry_eval('show-source TestClass')
          expect(result).not_to match(/available monkeypatches/)
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
          expect(out).to match(/class M/)
          expect(out).to match(/def alpha/)
          expect(out).to match(/def beta/)
        end

        it 'should be unable to find module source if no methods defined' do
          expect { pry_eval(TestHost::C, 'show-source') }
            .to raise_error(Pry::CommandError, /Couldn't locate/)
        end

        it(
          'displays method code (rather than class) if Pry started inside ' \
          'method binding'
        ) do
          out = TestHost::D.invoked_in_method
          expect(out).to match(/invoked_in_method/)
          expect(out).not_to match(/module D/)
        end

        it 'should display class source when inside instance' do
          out = pry_eval(TestHost::M.new, 'show-source')
          expect(out).to match(/class M/)
          expect(out).to match(/def alpha/)
          expect(out).to match(/def beta/)
        end

        it 'should allow options to be passed' do
          out = pry_eval(TestHost::M, 'show-source -b')
          expect(out).to match(/\d:\s*class M/)
          expect(out).to match(/\d:\s*def alpha/)
          expect(out).to match(/\d:\s*def beta/)
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
            expect(out).to match(/def d; end/)
            expect(out).not_to match(/def a; end/)
          end
        end

        describe "monkey-patched C modules" do
          # Monkey-patch Array and add 15 methods, so its internal rank is
          # high enough to make this definition primary.
          class Array
            15.times do |i|
              define_method(:"doge#{i}") do
                :"doge#{i}"
              end
            end
          end

          describe "when current context is a C object" do
            it "should display a warning, and not monkey-patched definition" do
              out = pry_eval([1, 2, 3], 'show-source')
              expect(out).not_to match(/doge/)
              expect(out).to match(/Pry cannot display the information/)
            end

            it "recommends to use the --all switch when other candidates are found" do
              out = pry_eval([], 'show-source')
              expect(out).to match(/'--all' switch/i)
            end
          end

          describe "when current context is something other than a C object" do
            it "should display a candidate, not a warning" do
              out = pry_eval('show-source Array')
              expect(out).to match(/doge/)
              expect(out).not_to match(/warning/i)
            end
          end
        end
      end
    end
  end

  describe "on commands" do
    let(:default_commands) { Pry.config.commands }

    let(:command_set) do
      Pry::CommandSet.new { import Pry::Commands }
    end

    before { Pry.config.commands = command_set }
    after { Pry.config.commands = default_commands }

    describe "block commands" do
      it 'should show source for an ordinary command' do
        command_set.command('foo', :body_of_foo) {}
        expect(pry_eval(binding, 'show-source foo')).to match(/:body_of_foo/)
      end

      it "should output source of commands using special characters" do
        command_set.command('!%$', 'I gots the yellow fever') {}
        expect(pry_eval(binding, 'show-source !%$')).to match(/yellow fever/)
      end

      it 'should show source for a command with spaces in its name' do
        command_set.command('foo bar', :body_of_foo_bar) {}
        expect(pry_eval(binding, 'show-source foo bar')).to match(/:body_of_foo_bar/)
      end

      it 'should show source for a command by listing name' do
        command_set.command(/foo(.*)/, :body_of_foo_bar_regex, listing: "bar") {}
        expect(pry_eval(binding, 'show-source bar')).to match(/:body_of_foo_bar_regex/)
      end
    end

    describe "create_command commands" do
      it 'should show source for a command' do
        command_set.create_command "foo", "babble" do
          def process
            :body_of_foo
          end
        end
        expect(pry_eval(binding, 'show-source foo')).to match(/:body_of_foo/)
      end

      it 'should show source for a command defined inside pry' do
        pry_eval %{
          pry_instance.commands.create_command "foo", "babble" do
            def process() :body_of_foo end
          end
        }
        expect(pry_eval(binding, 'show-source foo')).to match(/:body_of_foo/)
      end
    end

    describe "real class-based commands" do
      before do
        # rubocop:disable Style/ClassAndModuleChildren
        class ::TemporaryCommand < Pry::ClassCommand
          match 'temp-command'
          def process
            :body_of_temp
          end
        end
        # rubocop:enable Style/ClassAndModuleChildren

        Pry.config.commands.add_command(::TemporaryCommand)
      end

      after do
        Object.remove_const(:TemporaryCommand)
      end

      it 'should show source for a command' do
        expect(pry_eval('show-source temp-command')).to match(/:body_of_temp/)
      end

      it 'should show source for a command defined inside pry' do
        pry_eval %{
          class ::TemporaryCommandInPry < Pry::ClassCommand
            match 'temp-command-in-pry'
            def process() :body_of_temp end
          end
        }
        Pry.config.commands.add_command(::TemporaryCommandInPry)
        expect(pry_eval('show-source temp-command-in-pry')).to match(/:body_of_temp/)
        Object.remove_const(:TemporaryCommandInPry)
      end
    end
  end

  describe "should set _file_ and _dir_" do
    let(:tempfile) { Tempfile.new(%w[pry .rb]) }

    before do
      define_persistent_class(tempfile, <<-CLASS)
        class TestClass
          def alpha; end
        end
      CLASS
    end

    after do
      Object.remove_const(:TestClass)
      tempfile.unlink
    end

    it 'should set _file_ and _dir_ to file containing method source' do
      t = pry_tester
      t.process_command "show-source TestClass#alpha"

      path = tempfile.path.split('/')[0..-2].join('/')
      expect(t.pry.last_dir).to match(path)

      expect(t.pry.last_file).to match(tempfile.path)
    end
  end

  describe "can't find class/module code" do
    describe "for classes" do
      before do
        module Jesus
          module Pig
            def lillybing
              :lillybing
            end
          end

          class Brian; end
          class Jingle
            def a
              :doink
            end
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
        expect(t.last_output).to match(/doink/)
      end

      it 'ignores included modules' do
        t = pry_tester
        t.process_command "show-source Jesus::Jangle"
        expect(t.last_output).not_to match(/lillybing/)
      end

      it 'errors when class has no superclass to show' do
        t = pry_tester
        expect { t.process_command "show-source Jesus::Brian" }
          .to raise_error(Pry::CommandError, /Couldn't locate/)
      end

      it 'shows warning when reverting to superclass code' do
        t = pry_tester
        t.process_command "show-source Jesus::Jangle"
        expect(t.last_output).to match(
          /Warning.*?Cannot find.*?Jesus::Jangle.*Showing.*Jesus::Jingle instead/
        )
      end

      it(
        'shows nth level superclass code (when no intermediary ' \
        'superclasses have code either)'
      ) do
        t = pry_tester
        t.process_command "show-source Jesus::Bangle"
        expect(t.last_output).to match(/doink/)
      end

      it 'shows correct warning when reverting to nth level superclass' do
        t = pry_tester
        t.process_command "show-source Jesus::Bangle"
        expect(t.last_output).to match(
          /Warning.*?Cannot find.*?Jesus::Bangle.*Showing.*Jesus::Jingle instead/
        )
      end
    end

    describe "for modules" do
      before do
        module Jesus
          module Alpha
            def alpha
              :alpha
            end
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
        expect(t.last_output).to match(/alpha/)
      end

      it 'shows warning when reverting to included module code' do
        t = pry_tester
        t.process_command "show-source Jesus::Beta"
        expect(t.last_output).to match(
          /Warning.*?Cannot find.*?Jesus::Beta.*Showing.*Jesus::Alpha instead/
        )
      end

      it 'errors when module has no included module to show' do
        t = pry_tester
        expect { t.process_command "show-source Jesus::Zeta" }
          .to raise_error(Pry::CommandError, /Couldn't locate/)
      end

      it(
        'shows nth level included module code (when no intermediary modules ' \
        'have code either)'
      ) do
        t = pry_tester
        t.process_command "show-source Jesus::Gamma"
        expect(t.last_output).to match(/alpha/)
      end

      it 'shows correct warning when reverting to nth level included module' do
        t = pry_tester
        t.process_command "show-source Jesus::Gamma"
        expect(t.last_output).to match(
          /Warning.*?Cannot find.*?Jesus::Gamma.*Showing.*Jesus::Alpha instead/
        )
      end
    end
  end

  describe "show-source --doc" do
    context "when given a class with a doc" do
      before do
        # Foo has docs.
        class Foo
          def bar; end
        end
      end

      after { Object.remove_const(:Foo) }

      it "shows documentation for the code object along with source code" do
        expect(pry_eval(binding, "show-source Foo -d")).to match(
          /Foo has docs\.\n\s+class Foo/
        )
      end
    end

    context "when given a module with a doc" do
      before do
        # TestMod has docs
        module TestMod
          def foo; end
        end
      end

      after { Object.remove_const(:TestMod) }

      it "shows documentation for the code object along with source code" do
        expect(pry_eval(binding, "show-source TestMod -d")).to match(
          /TestMod has docs\n\s+module TestMod/
        )
      end
    end

    context "when the Const = Class.new syntax is used" do
      before do
        # TestClass has docs
        TestClass = Class.new do
          def foo; end
        end
      end

      after { Object.remove_const(:TestClass) }

      it "shows documentation for the class" do
        expect(pry_eval(binding, "show-source TestClass -d")).to match(
          /TestClass has docs\n\s+TestClass = Class.new/
        )
      end
    end

    context "when the Const = Module.new syntax is used" do
      before do
        # TestMod has docs
        TestMod = Module.new do
          def foo; end
        end
      end

      after { Object.remove_const(:TestMod) }

      it "shows documentation for the module" do
        expect(pry_eval(binding, "show-source TestMod -d")).to match(
          /TestMod has docs\n\s+TestMod = Module.new/
        )
      end
    end

    context "when given a class defined in a REPL session" do
      after { Object.remove_const(:TobinaMyDog) }

      it "shows documentation for the class" do
        t = pry_tester
        t.eval <<-RUBY
          # hello tobina
          class TobinaMyDog
            def woof
            end
          end
        RUBY
        expect(t.eval('show-source -d TobinaMyDog')).to match(/hello tobina/)
      end
    end

    context "when the current context is a non-nested class" do
      before do
        # top-level beta
        class BetaClass
          def alpha; end
        end

        class AlphaClass
          # nested beta
          class BetaClass
            def beta; end
          end
        end
      end

      after do
        [:BetaClass, :AlphaClass].each { |name| Object.remove_const(name) }
      end

      it "shows docs for the nested classes" do
        expect(pry_eval(AlphaClass, "show-source -d BetaClass"))
          .to match(/nested beta/)
      end
    end

    context "when given a nested class" do
      before do
        # top-level beta
        class BetaClass
          def alpha; end
        end

        class AlphaClass
          # nested beta
          class BetaClass
            def beta; end
          end
        end
      end

      after do
        [:BetaClass, :AlphaClass].each { |name| Object.remove_const(name) }
      end

      it "shows docs for the nested classes" do
        expect(pry_eval(AlphaClass, "show-source -d AlphaClass::BetaClass"))
          .to match(/nested beta/)
      end
    end

    context "when given a method with a doc" do
      before do
        @obj = Object.new

        # test doc
        def @obj.test_method; end
      end

      it "finds the method's documentation" do
        expect(pry_eval(binding, "show-source -d @obj.test_method"))
          .to match(/test doc/)
      end
    end

    context "when #call is defined on Symbol" do
      before do
        class Symbol
          def call; end
        end

        @obj = Object.new

        # test doc
        def @obj.test_method; end
      end

      after { Symbol.class_eval { undef :call } }

      it "still finds documentation" do
        expect(pry_eval(binding, "show-source -d @obj.test_method"))
          .to match(/test doc/)
      end
    end

    context "when no docs can be found for the given class" do
      before do
        class TestClass
          def test_method; end
        end
      end

      after { Object.remove_const(:TestClass) }

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, "show-source -d TestClass") }
          .to raise_error(Pry::CommandError)
      end
    end

    context "when no docs can be found for the given method" do
      before do
        @obj = Object.new
        def @obj.test_method; end
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, "show-source -d @obj.test_method") }
          .to raise_error(Pry::CommandError)
      end
    end

    context "when the --line-numbers switch is provided" do
      before do
        @obj = Object.new

        # test doc
        def @obj.test_method; end
      end

      it "outputs a method's docs with line numbers" do
        expect(pry_eval(binding, "show-source -d --line-numbers @obj.test_method"))
          .to match(/\d: test doc/)
      end
    end

    context "when the --base-one switch is provided" do
      before do
        @obj = Object.new

        # test doc
        def @obj.test_method; end
      end

      it "outputs a method's docs with line numbering starting at 1" do
        expect(pry_eval(binding, "show-source -d --base-one @obj.test_method"))
          .to match(/1: test doc/)
      end
    end

    context "when the current context is a method" do
      it "outputs the method without needing to use its name" do
        obj = Object.new

        # test method
        def obj.test_method
          pry_eval(binding, 'show-source -d')
        end

        expect(obj.test_method).to match(/test method/)
      end
    end

    context "when given a proc" do
      it "should show documentation for object" do
        # this is a documentation
        _the_proc = proc { puts 'hello world!' }

        expect(mock_pry(binding, "show-source -d _the_proc"))
          .to match(/this is a documentation/)
      end
    end

    context "when no class/module arg is given" do
      before do
        module TestHost
          # hello there froggy
          module M
            def d; end

            def e; end
          end
        end
      end

      after { Object.remove_const(:TestHost) }

      it "returns the doc for the current module" do
        expect(pry_eval(TestHost::M, 'show-source -d'))
          .to match(/hello there froggy/)
      end
    end

    context "when given a 'broken' module" do
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

      after { Object.remove_const(:TestHost) }

      # FIXME: THis is nto a good spec anyway, because i dont think it
      # SHOULD skip!
      it "skips over the module" do
        output = pry_eval('show-source -d TestHost::M')
        expect(output).to match(/goodbye/)
        expect(output).not_to match(/hello/)
      end
    end

    describe "should set _file_ and _dir_" do
      let(:tempfile) { Tempfile.new(%w[pry .rb]) }

      before do
        define_persistent_class(tempfile, <<-CLASS)
          class TestClass
            # this is alpha
            def alpha; end
          end
        CLASS
      end

      after do
        Object.remove_const(:TestClass)
        tempfile.unlink
      end

      it "sets _file_ and _dir_ to file containing method source" do
        t = pry_tester
        t.process_command "show-source -d TestClass#alpha"

        path = tempfile.path.split('/')[0..-2].join('/')
        expect(t.pry.last_dir).to match(path)

        expect(t.pry.last_file).to match(tempfile.path)
      end
    end

    context "when provided a class without docs that has a superclass with docs" do
      before do
        # parent class
        class Parent
          def foo; end
        end

        class Child < Parent; end
      end

      after do
        [:Child, :Parent].each { |name| Object.remove_const(name) }
      end

      it "shows the docs of the superclass" do
        expect(pry_eval(binding, 'show-source -d Child')).to match(/parent class/)
      end

      it "shows a warning about superclass reversion" do
        expect(pry_eval(binding, 'show-source -d Child')).to match(
          /Warning.*?Cannot find.*?Child.*Showing.*Parent instead/
        )
      end
    end

    context "when provided a class without docs that has nth superclass with docs" do
      before do
        # grandparent class
        class Grandparent
          def foo; end
        end

        class Parent < Grandparent; end
        class Child < Parent; end
      end

      after do
        [:Grandparent, :Child, :Parent].each { |name| Object.remove_const(name) }
      end

      it "shows the docs of the superclass" do
        expect(pry_eval(binding, 'show-source -d Child'))
          .to match(/grandparent class/)
      end

      it "shows a warning about superclass reversion" do
        expect(pry_eval(binding, 'show-source -d Child')).to match(
          /Warning.*?Cannot find.*?Child.*Showing.*Grandparent instead/
        )
      end
    end

    context "when provided a class without docs that has a superclass without docs" do
      before do
        class Parent
          def foo; end
        end

        class Child < Parent; end
      end

      after do
        [:Child, :Parent].each { |name| Object.remove_const(name) }
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, 'show-source -d Child') }
          .to raise_error(Pry::CommandError)
      end
    end

    context "when the module with docs was included in another module" do
      before do
        # mod module doc
        module Alpha
          def foo; end
        end

        module Beta
          include Alpha
        end
      end

      after do
        [:Beta, :Alpha].each { |name| Object.remove_const(name) }
      end

      it "shows the included module's doc" do
        expect(pry_eval(binding, 'show-source -d Beta'))
          .to match(/mod module doc/)
      end

      it "shows a warning about the included module reversion" do
        expect(pry_eval(binding, 'show-source -d Beta')).to match(
          /Warning.*?Cannot find.*?Beta.*Showing.*Alpha instead/
        )
      end
    end

    context "when both the base mod and the included module have no docs" do
      before do
        module Alpha
          def foo; end
        end

        module Beta
          include Alpha
        end
      end

      after do
        [:Beta, :Alpha].each { |name| Object.remove_const(name) }
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, 'show-source -d Beta') }
          .to raise_error(Pry::CommandError)
      end
    end

    context "when included module has docs and there are intermediary docless modules" do
      before do
        # alpha doc
        module Alpha
          def alpha; end
        end

        module Beta
          include Alpha
        end

        module Gamma
          include Beta
        end
      end

      after do
        [:Gamma, :Beta, :Alpha].each { |name| Object.remove_const(name) }
      end

      it "shows nth level included module doc" do
        expect(pry_eval(binding, 'show-source -d Gamma')).to match(/alpha doc/)
      end

      it "shows a warning about module reversion" do
        expect(pry_eval(binding, 'show-source -d Gamma')).to match(
          /Warning.*?Cannot find.*?Gamma.*Showing.*Alpha instead/
        )
      end
    end

    context "when the --super switch is provided" do
      before do
        class Grandparent
          # grandparent init
          def initialize; end
        end

        class Parent < Grandparent
          # parent init
          def initialize; end
        end

        class Child < Parent
          # child init
          def initialize; end
        end

        @obj = Child.new

        # instance init
        def @obj.initialize; end
      end

      after do
        [:Grandparent, :Parent, :Child].each { |name| Object.remove_const(name) }
      end

      context "and when it's passed once" do
        it "finds the super method docs" do
          expect(pry_eval(binding, 'show-source -d --super @obj.initialize'))
            .to match(/child init/)
        end
      end

      context "and when it's passed twice" do
        it "finds the parent method docs" do
          expect(pry_eval(binding, 'show-source -d -ss @obj.initialize'))
            .to match(/parent init/)
        end
      end

      context "and when it's passed thrice" do
        it "finds the grandparent method docs" do
          expect(pry_eval(binding, 'show-source -d -sss @obj.initialize'))
            .to match(/parent init/)
        end
      end

      context "and when the super method doesn't exist" do
        it "raises Pry::CommandError" do
          expect { pry_eval(binding, 'show-source -d -ssss @obj.initialize') }
            .to raise_error(Pry::CommandError)
        end
      end

      context "and when the explicit argument is not provided" do
        let(:son) { Child.new }
        it "finds super method docs without explicit method argument" do
          # son init
          def son.initialize
            pry_eval(binding, 'show-source -d --super')
          end

          expect(son.initialize).to match(/child init/)
        end

        it "finds super method docs with multiple `--super` switches" do
          son.extend(
            Module.new do
              def initialize; end
            end
          )

          # son init
          def son.initialize
            pry_eval(binding, 'show-source -d --super --super')
          end

          expect(son.initialize).to match(/child init/)
        end
      end
    end

    describe "code highlighting" do
      context "when there's code in the docs" do
        let(:klass) do
          Class.new do
            # This can initialize your class:
            #
            #   a = klass.new :foo
            #
            # @param foo
            def initialize(foo); end
          end
        end

        it "highlights the code" do
          expect(pry_eval(binding, 'show-source -d klass#initialize'))
            .to match(/klass.new :foo/)

          # We don't want the test to rely on which colour codes are there, so
          # we just assert that something is being colorized.
          expect(
            pry_eval(
              binding,
              'pry_instance.color = true',
              "show-source -d klass#initialize"
            )
          ).not_to match(/klass.new :foo/)
        end
      end

      context "when there's inline code in the docs" do
        let(:klass) do
          Class.new do
            # After initializing your class with `klass.new(:inline)`, go have
            # fun!
            #
            # @param foo
            def initialize(foo); end
          end
        end

        it "highlights the code" do
          expect(pry_eval(binding, 'show-source -d klass#initialize'))
            .to match(/klass.new\(:inline\)/)

          # We don't want the test to rely on which colour codes are there, so
          # we just assert that something is being colorized.
          expect(
            pry_eval(
              binding,
              'pry_instance.color = true',
              "show-source -d klass#initialize"
            )
          ).not_to match(/klass.new\(:inline\)/)
        end
      end

      context "when there's inline code with backticks the docs" do
        let(:klass) do
          Class.new do
            # Convert aligned output (from many shell commands) into nested arrays:
            #
            #   a = decolumnize `ls -l $HOME`
            #
            # @param output
            def decolumnize(output); end
          end
        end

        it "doesn't highlight the backticks" do
          output = pry_eval(
            binding,
            'pry_instance.color = true',
            "show-source -d klass#decolumnize"
          )

          expect(output).to match(/ls -l \$HOME/)
          expect(output).not_to match(/`ls -l \$HOME`/)
        end
      end
    end

    describe "the --all switch behavior" do
      let(:tempfile) { Tempfile.new(%w[pry .rb]) }

      context "when there are monkeypatches in different files" do
        before do
          define_persistent_class(tempfile, <<-CLASS)
            # file monkeypatch
            class TestClass
              def alpha; end
            end
          CLASS

          # local monkeypatch
          class TestClass
            def beta; end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "shows them" do
          result = pry_eval(binding, 'show-source -d TestClass -a')
          expect(result).to match(/file monkeypatch/)
          expect(result).to match(/local monkeypatch/)
        end
      end

      context "when --all is not used but there are multiple monkeypatches" do
        before do
          define_persistent_class(tempfile, <<-CLASS)
            # alpha
            class TestClass
              def alpha; end
            end
          CLASS

          class TestClass
            def beta; end
          end
        end

        after do
          Object.remove_const(:TestClass)
          tempfile.unlink
        end

        it "correctly displays the number of monkeypatches" do
          result = pry_eval(binding, 'show-source -d TestClass')
          expect(result).to match(/Number of monkeypatches: 2/)
        end

        it "displays the original definition first" do
          result = pry_eval(binding, 'show-source -d TestClass')
          expect(result).to match(/alpha/)
        end

        it "mentions available monkeypatches" do
          result = pry_eval(binding, 'show-source -d TestClass')
          expect(result).to match(/available monkeypatches/)
        end
      end

      context "when --all is not used and there's only 1 candidate for the class" do
        before do
          # alpha
          class TestClass
            def alpha; end
          end
        end

        after { Object.remove_const(:TestClass) }

        it "doesn't mention anything about monkeypatches" do
          result = pry_eval(binding, 'show-source -d TestClass')
          expect(result).not_to match(/available monkeypatches/)
        end
      end
    end

    context "when used against a command" do
      let(:default_commands) { Pry.config.commands }

      let(:command_set) do
        Pry::CommandSet.new { import Pry::Commands }
      end

      before { Pry.config.commands = command_set }
      after { Pry.config.commands = default_commands }

      it "displays help for a specific command" do
        expect(pry_eval(binding, 'show-source -d ls')).to match(/Usage: ls/)
      end

      it "displays help for a regex command with a \"listing\"" do
        command_set.command(/bar(.*)/, 'Test listing', listing: 'foo') {}
        expect(pry_eval(binding, 'show-source -d foo')).to match(/Test listing/)
      end

      it "displays help for a command with a spaces in its name" do
        command_set.command('command with spaces', 'command with spaces desc') {}
        expect(pry_eval(binding, 'show-source -d command with spaces')).to match(
          /command with spaces desc/
        )
      end

      describe "class commands" do
        before do
          # pretty pink pincers
          class LobsterLady < Pry::ClassCommand
            match 'lobster-lady'
            description 'nada.'
            def process
              'lobster'
            end
          end

          command_set.add_command(LobsterLady)
        end

        after { Object.remove_const(:LobsterLady) }

        context "when looking up by command name" do
          it "displays help" do
            expect(pry_eval('show-source -d lobster-lady')).to match(/nada/)
          end
        end

        context "when class is used (rather than command name) is used for lookup" do
          it "displays actual preceding comment for a class command" do
            expect(pry_eval('show-source -d LobsterLady')).to match(/pretty pink pincers/)
          end
        end
      end
    end
  end
end
