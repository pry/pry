require_relative '../helper'
require "fixtures/show_source_doc_examples"

describe "show-doc" do
  before do
    @o = Object.new

    # sample doc
    def @o.sample_method
      :sample
    end

    def @o.no_docs;end

  end

  it 'should output a method\'s documentation' do
    expect(pry_eval(binding, "show-doc @o.sample_method")).to match(/sample doc/)
  end

  it 'should raise exception when cannot find docs' do
    expect { pry_eval(binding, "show-doc @o.no_docs") }.to raise_error Pry::CommandError
  end

  it 'should output a method\'s documentation with line numbers' do
    expect(pry_eval(binding, "show-doc @o.sample_method -l")).to match(/\d: sample doc/)
  end

  it 'should output a method\'s documentation with line numbers (base one)' do
    expect(pry_eval(binding, "show-doc @o.sample_method -b")).to match(/1: sample doc/)
  end

  it 'should output a method\'s documentation if inside method without needing to use method name' do
    # sample comment
    def @o.sample
      pry_eval(binding, 'show-doc').should =~ /sample comment/
    end
    @o.sample
  end

  describe "finding find super method docs with help of `--super` switch" do
    before do
      class Daddy
        # daddy initialize!
        def initialize(*args); end
      end

      class Classy < Daddy
        # classy initialize!
        def initialize(*args); end
      end

      class Grungy < Classy
        # grungy initialize??
        def initialize(*args); end
      end

      @o = Grungy.new

      # instancey initialize!
      def @o.initialize; end
    end

    after do
      Object.remove_const(:Grungy)
      Object.remove_const(:Classy)
      Object.remove_const(:Daddy)
    end

    it "finds super method docs" do
      output = pry_eval(binding, 'show-doc --super @o.initialize')
      expect(output).to match(/grungy initialize/)
    end

    it "traverses ancestor chain and finds super method docs" do
      output = pry_eval(binding, 'show-doc -ss @o.initialize')
      expect(output).to match(/classy initialize/)
    end

    it "traverses ancestor chain even higher and finds super method doc" do
      output = pry_eval(binding, 'show-doc @o.initialize -sss')
      expect(output).to match(/daddy initialize/)
    end

    it "finds super method docs without explicit method argument" do
      fatty = Grungy.new

      # fatty initialize!
      def fatty.initialize
        pry_eval(binding, 'show-doc --super')
      end

      output = fatty.initialize
      expect(output).to match(/grungy initialize/)
    end

    it "finds super method docs without `--super` but with the `super` keyword" do
      fatty = Grungy.new

      fatty.extend Module.new {
        def initialize
          :nibble
        end
      }

      # fatty initialize!
      def fatty.initialize
        pry_eval(binding, 'show-doc --super --super')
      end

      output = fatty.initialize
      expect(output).to match(/grungy initialize/)
    end
  end

  describe "rdoc highlighting" do
    it "should syntax highlight code in rdoc" do
      _c = Class.new{
        # This can initialize your class:
        #
        #   a = _c.new :foo
        #
        # @param foo
        def initialize(foo); end
      }

      begin
        t = pry_tester(binding)
        expect(t.eval("show-doc _c#initialize")).to match(/_c.new :foo/)
        Pry.config.color = true
        # I don't want the test to rely on which colour codes are there, just to
        # assert that "something" is being colourized.
        expect(t.eval("show-doc _c#initialize")).not_to match(/_c.new :foo/)
      ensure
        Pry.config.color = false
      end
    end

    it "should syntax highlight `code` in rdoc" do
      _c = Class.new{
        # After initializing your class with `_c.new(:foo)`, go have fun!
        #
        # @param foo
        def initialize(foo); end
      }

      begin
        t = pry_tester(binding)
        expect(t.eval("show-doc _c#initialize")).to match(/_c.new\(:foo\)/)
        Pry.config.color = true
        # I don't want the test to rely on which colour codes are there, just to
        # assert that "something" is being colourized.
        expect(t.eval("show-doc _c#initialize")).not_to match(/_c.new\(:foo\)/)
      ensure
        Pry.config.color = false
      end

    end

    it "should not syntax highlight `` inside code" do
      _c = Class.new{
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
        expect(t.eval("show-doc _c#decolumnize")).to match(/ls -l \$HOME/)
        expect(t.eval("show-doc _c#decolumnize")).not_to match(/`ls -l \$HOME`/)
      ensure
        Pry.config.color = false
      end
    end
  end

  describe "on sourcable objects" do
    it "should show documentation for object" do
      # this is a documentation
      _hello = proc { puts 'hello world!' }
      expect(mock_pry(binding, "show-doc _hello")).to match(/this is a documentation/)
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
        expect(pry_eval("show-doc ShowSourceTestClass")).to match(
          /god this is boring1/
        )
      end

      it 'should show docs for a module' do
        expect(pry_eval("show-doc ShowSourceTestModule")).to match(
          /god this is boring2/
        )
      end

      it 'should show docs for a class when Const = Class.new syntax is used' do
        expect(pry_eval("show-doc ShowSourceTestClassWeirdSyntax")).to match(
          /god this is boring3/
        )
      end

      it 'should show docs for a module when Const = Module.new syntax is used' do
        expect(pry_eval("show-doc ShowSourceTestModuleWeirdSyntax")).to match(
          /god this is boring4/
        )
      end
    end

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
        expect(t.eval('show-doc TobinaMyDog')).to match(/hello tobina/)
        Object.remove_const :TobinaMyDog
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

        expect(pry_eval(AlphaClass, "show-doc BetaClass")).to match(/nested beta/)
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

        expect(pry_eval("show-doc AlphaClass::BetaClass")).to match(
          /nested beta/
        )
      end
    end

    describe "show-doc -a" do
      it 'should show the docs for all monkeypatches defined in different files' do
        # local monkeypatch
        class TestClassForShowSource
          def epsilon
          end
        end

        result = pry_eval("show-doc TestClassForShowSource -a")
        expect(result).to match(/used by/)
        expect(result).to match(/local monkeypatch/)
      end

      describe "messages relating to -a" do
        it "displays the original definition by default (not a doc of a monkeypatch)" do
          class TestClassForCandidatesOrder
            def beta
            end
          end

          result = pry_eval("show-doc TestClassForCandidatesOrder")
          expect(result).to match(/Number of monkeypatches: 2/)
          expect(result).to match(/The first definition/)
        end

        it 'indicates all available monkeypatches can be shown with -a ' \
          '(when -a not used and more than one candidate exists for class)' do
          # Still reading boring tests, eh?
          class TestClassForShowSource
            def delta
            end
          end

          result = pry_eval('show-doc TestClassForShowSource')
          expect(result).to match(/available monkeypatches/)
        end

        it 'shouldnt say anything about monkeypatches when only one candidate exists for selected class' do
          # Do not remove me.
          class Aarrrrrghh
            def o;end
          end

          result = pry_eval('show-doc Aarrrrrghh')
          expect(result).not_to match(/available monkeypatches/)
          Object.remove_const(:Aarrrrrghh)
        end
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
        expect(pry_eval(TestHost::M, "show-doc")).to match(/hello there froggy/)
      end
    end

    # FIXME: THis is nto a good spec anyway, because i dont think it
    # SHOULD skip!
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
        expect(result).to match(/goodbye/)
        expect(result).not_to match(/hello/)
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
      expect(pry_eval('show-doc ls')).to match(/Usage: ls/)
    end

    it 'should display help for a regex command with a "listing"' do
      @set.command(/bar(.*)/, "Test listing", :listing => "foo") do; end
      expect(pry_eval('show-doc foo')).to match(/Test listing/)
    end

    it 'should display help for a command with a spaces in its name' do
      @set.command "command with spaces", "description of a command with spaces" do; end
      expect(pry_eval('show-doc command with spaces')).to match(/description of a command with spaces/)
    end

    describe "class commands" do
      before do
        # pretty pink pincers
        class LobsterLady < Pry::ClassCommand
          match "lobster-lady"
          description "nada."
          def process
            "lobster"
          end
        end

        Pry.config.commands.add_command(LobsterLady)
      end

      after do
        Object.remove_const(:LobsterLady)
      end

      it 'should display "help" when looking up by command name' do
        expect(pry_eval('show-doc lobster-lady')).to match(/nada/)
        Pry.config.commands.delete("lobster-lady")
      end

      it 'should display actual preceding comment for a class command, when class is used (rather than command name) when looking up' do
        expect(pry_eval('show-doc LobsterLady')).to match(/pretty pink pincers/)
        Pry.config.commands.delete("lobster-lady")
      end
    end
  end

  describe "should set _file_ and _dir_" do
    it 'should set _file_ and _dir_ to file containing method source' do
      t = pry_tester
      t.process_command "show-doc TestClassForShowSource#alpha"
      expect(t.pry.last_file).to match(/show_source_doc_examples/)
      expect(t.pry.last_dir).to match(/fixtures/)
    end
  end

  unless Pry::Helpers::BaseHelpers.rbx?
    describe "can't find class docs" do
      describe "for classes" do
        before do
          module Jesus
            class Brian; end

            # doink-doc
            class Jingle
              def a; :doink; end
            end

            class Jangle < Jingle; end
            class Bangle < Jangle; end
          end
        end

        after do
          Object.remove_const(:Jesus)
        end

        it 'shows superclass doc' do
          t = pry_tester
          t.process_command "show-doc Jesus::Jangle"
          expect(t.last_output).to match(/doink-doc/)
        end

        it 'errors when class has no superclass to show' do
          t = pry_tester
          expect { t.process_command "show-doc Jesus::Brian" }.to raise_error(Pry::CommandError, /Couldn't locate/)
        end

        it 'shows warning when reverting to superclass docs' do
          t = pry_tester
          t.process_command "show-doc Jesus::Jangle"
          expect(t.last_output).to match(/Warning.*?Cannot find.*?Jesus::Jangle.*Showing.*Jesus::Jingle instead/)
        end

        it 'shows nth level superclass docs (when no intermediary superclasses have code either)' do
          t = pry_tester
          t.process_command "show-doc Jesus::Bangle"
          expect(t.last_output).to match(/doink-doc/)
        end

        it 'shows correct warning when reverting to nth level superclass' do
          t = pry_tester
          t.process_command "show-doc Jesus::Bangle"
          expect(t.last_output).to match(/Warning.*?Cannot find.*?Jesus::Bangle.*Showing.*Jesus::Jingle instead/)
        end
      end

      describe "for modules" do
        before do
          module Jesus

            # alpha-doc
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

        it 'shows included module doc' do
          t = pry_tester
          t.process_command "show-doc Jesus::Beta"
          expect(t.last_output).to match(/alpha-doc/)
        end

        it 'shows warning when reverting to included module doc' do
          t = pry_tester
          t.process_command "show-doc Jesus::Beta"
          expect(t.last_output).to match(/Warning.*?Cannot find.*?Jesus::Beta.*Showing.*Jesus::Alpha instead/)
        end

        it 'errors when module has no included module to show' do
          t = pry_tester
          expect { t.process_command "show-source Jesus::Zeta" }.to raise_error(Pry::CommandError, /Couldn't locate/)
        end

        it 'shows nth level included module doc (when no intermediary modules have code either)' do
          t = pry_tester
          t.process_command "show-doc Jesus::Gamma"
          expect(t.last_output).to match(/alpha-doc/)
        end

        it 'shows correct warning when reverting to nth level included module' do
          t = pry_tester
          t.process_command "show-source Jesus::Gamma"
          expect(t.last_output).to match(/Warning.*?Cannot find.*?Jesus::Gamma.*Showing.*Jesus::Alpha instead/)
        end
      end
    end
  end
end
