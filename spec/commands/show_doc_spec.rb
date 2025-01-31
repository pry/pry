# frozen_string_literal: true

describe "show-doc" do
  def define_persistent_class(file, class_body)
    file.puts(class_body)
    file.close
    require(file.path)
  end

  before do
    @obj = Object.new

    # obj docs
    def @obj.sample_method; end
  end

  it "shows docs" do
    expect(pry_eval(binding, 'show-doc @obj.sample_method')).to match(/obj docs/)
  end

  describe "show-doc --doc" do
    context "when given a class with a doc" do
      before do
        # Foo has docs.
        class Foo
          def bar; end
        end
      end

      after { Object.remove_const(:Foo) }

      it "shows documentation for the code object" do
        expect(pry_eval(binding, "show-doc Foo")).to match(
          /Foo has docs\.\n/
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

      it "shows documentation for the code object" do
        expect(pry_eval(binding, "show-doc TestMod")).to match(
          /TestMod has docs\n/
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
        expect(pry_eval(binding, "show-doc TestClass")).to match(
          /TestClass has docs/
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
        expect(pry_eval(binding, "show-doc TestMod")).to match(
          /TestMod has docs\n/
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
        expect(t.eval('show-doc TobinaMyDog')).to match(/hello tobina/)
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
        %i[BetaClass AlphaClass].each { |name| Object.remove_const(name) }
      end

      it "shows docs for the nested classes" do
        expect(pry_eval(AlphaClass, "show-doc BetaClass"))
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
        %i[BetaClass AlphaClass].each { |name| Object.remove_const(name) }
      end

      it "shows docs for the nested classes" do
        expect(pry_eval(AlphaClass, "show-doc AlphaClass::BetaClass"))
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
        expect(pry_eval(binding, "show-doc @obj.test_method"))
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
        expect(pry_eval(binding, "show-doc @obj.test_method"))
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
        expect { pry_eval(binding, "show-doc TestClass") }
          .to raise_error(Pry::CommandError)
      end
    end

    context "when no docs can be found for the given method" do
      before do
        @obj = Object.new
        def @obj.test_method; end
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, "show-doc @obj.test_method") }
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
        expect(pry_eval(binding, "show-doc --line-numbers @obj.test_method"))
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
        expect(pry_eval(binding, "show-doc --base-one @obj.test_method"))
          .to match(/1: test doc/)
      end
    end

    context "when the current context is a method" do
      it "outputs the method without needing to use its name" do
        obj = Object.new

        # test method
        def obj.test_method
          pry_eval(binding, 'show-doc')
        end

        expect(obj.test_method).to match(/test method/)
      end
    end

    context "when given a proc" do
      it "should show documentation for object" do
        # this is a documentation
        _the_proc = proc { puts 'hello world!' }

        expect(mock_pry(binding, "show-doc _the_proc"))
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
        expect(pry_eval(TestHost::M, 'show-doc'))
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
        output = pry_eval('show-doc TestHost::M')
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
        t.process_command "show-doc TestClass#alpha"

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
        %i[Child Parent].each { |name| Object.remove_const(name) }
      end

      it "shows the docs of the superclass" do
        expect(pry_eval(binding, 'show-doc Child')).to match(/parent class/)
      end

      it "shows a warning about superclass reversion" do
        expect(pry_eval(binding, 'show-doc Child')).to match(
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
        %i[Grandparent Child Parent].each { |name| Object.remove_const(name) }
      end

      it "shows the docs of the superclass" do
        expect(pry_eval(binding, 'show-doc Child'))
          .to match(/grandparent class/)
      end

      it "shows a warning about superclass reversion" do
        expect(pry_eval(binding, 'show-doc Child')).to match(
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
        %i[Child Parent].each { |name| Object.remove_const(name) }
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, 'show-doc Child') }
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
        %i[Beta Alpha].each { |name| Object.remove_const(name) }
      end

      it "shows the included module's doc" do
        expect(pry_eval(binding, 'show-doc Beta'))
          .to match(/mod module doc/)
      end

      it "shows a warning about the included module reversion" do
        expect(pry_eval(binding, 'show-doc Beta')).to match(
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
        %i[Beta Alpha].each { |name| Object.remove_const(name) }
      end

      it "raises Pry::CommandError" do
        expect { pry_eval(binding, 'show-doc Beta') }
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
        %i[Gamma Beta Alpha].each { |name| Object.remove_const(name) }
      end

      it "shows nth level included module doc" do
        expect(pry_eval(binding, 'show-doc Gamma')).to match(/alpha doc/)
      end

      it "shows a warning about module reversion" do
        expect(pry_eval(binding, 'show-doc Gamma')).to match(
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
        %i[Grandparent Parent Child].each { |name| Object.remove_const(name) }
      end

      context "and when it's passed once" do
        it "finds the super method docs" do
          expect(pry_eval(binding, 'show-doc --super @obj.initialize'))
            .to match(/child init/)
        end
      end

      context "and when it's passed twice" do
        it "finds the parent method docs" do
          expect(pry_eval(binding, 'show-doc -ss @obj.initialize'))
            .to match(/parent init/)
        end
      end

      context "and when it's passed thrice" do
        it "finds the grandparent method docs" do
          expect(pry_eval(binding, 'show-doc -sss @obj.initialize'))
            .to match(/parent init/)
        end
      end

      context "and when the super method doesn't exist" do
        it "raises Pry::CommandError" do
          expect { pry_eval(binding, 'show-doc -ssss @obj.initialize') }
            .to raise_error(Pry::CommandError)
        end
      end

      context "and when the explicit argument is not provided" do
        let(:son) { Child.new }
        it "finds super method docs without explicit method argument" do
          # son init
          def son.initialize
            pry_eval(binding, 'show-doc --super')
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
            pry_eval(binding, 'show-doc --super --super')
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
          expect(pry_eval(binding, 'show-doc klass#initialize'))
            .to match(/klass.new :foo/)

          # We don't want the test to rely on which colour codes are there, so
          # we just assert that something is being colorized.
          expect(
            pry_eval(
              binding,
              'pry_instance.color = true',
              "show-doc klass#initialize"
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
          expect(pry_eval(binding, 'show-doc klass#initialize'))
            .to match(/klass.new\(:inline\)/)

          # We don't want the test to rely on which colour codes are there, so
          # we just assert that something is being colorized.
          expect(
            pry_eval(
              binding,
              'pry_instance.color = true',
              "show-doc klass#initialize"
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
            "show-doc klass#decolumnize"
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
          result = pry_eval(binding, 'show-doc TestClass -a')
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
          result = pry_eval(binding, 'show-doc TestClass')
          expect(result).to match(/Number of monkeypatches: 2/)
        end

        it "displays the original definition first" do
          result = pry_eval(binding, 'show-doc TestClass')
          expect(result).to match(/alpha/)
        end

        it "mentions available monkeypatches" do
          result = pry_eval(binding, 'show-doc TestClass')
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
          result = pry_eval(binding, 'show-doc TestClass')
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
        expect(pry_eval(binding, 'show-doc ls')).to match(/Usage: ls/)
      end

      it "displays help for a regex command with a \"listing\"" do
        command_set.command(/bar(.*)/, 'Test listing', listing: 'foo') {}
        expect(pry_eval(binding, 'show-doc foo')).to match(/Test listing/)
      end

      it "displays help for a command with a spaces in its name" do
        command_set.command('command with spaces', 'command with spaces desc') {}
        expect(pry_eval(binding, 'show-doc command with spaces')).to match(
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
            expect(pry_eval('show-doc lobster-lady')).to match(/nada/)
          end
        end

        context "when class is used (rather than command name) is used for lookup" do
          it "displays actual preceding comment for a class command" do
            expect(pry_eval('show-doc LobsterLady')).to match(/pretty pink pincers/)
          end
        end
      end
    end
  end
end
