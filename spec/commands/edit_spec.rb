# frozen_string_literal: true

require 'pathname'
require 'tempfile'

describe "edit" do
  before do
    @old_editor = Pry.config.editor
    @file = @line = @contents = nil
    Pry.config.editor = lambda do |file, line|
      @file = file
      @line = line
      @contents = File.read(@file)
      nil
    end
  end

  after do
    Pry.config.editor = @old_editor
  end

  describe "with FILE" do
    before do
      # OS-specific tempdir name. For GNU/Linux it's "tmp", for Windows it's
      # something "Temp".
      @tf_dir =
        if Pry::Helpers::Platform.mri_19?
          Pathname.new(Dir::Tmpname.tmpdir)
        else
          Pathname.new(Dir.tmpdir)
        end

      @tf_path = File.expand_path(File.join(@tf_dir.to_s, 'bar.rb'))
      FileUtils.touch(@tf_path)
    end

    after do
      FileUtils.rm(@tf_path) if File.exist?(@tf_path)
    end

    it "should not allow patching any known kind of file" do
      ["file.rb", "file.c", "file.py", "file.yml", "file.gemspec",
       "/tmp/file", "\\\\Temp\\\\file"].each do |file|
        expect { pry_eval "edit -p #{file}" }
          .to raise_error(NotImplementedError, /Cannot yet patch false objects!/)
      end
    end

    it "should invoke Pry.config.editor with absolutified filenames" do
      pry_eval 'edit lib/pry.rb'
      expect(@file).to eq File.expand_path('lib/pry.rb')

      pry_eval "edit #{@tf_path}"
      expect(@file).to eq @tf_path
    end

    it "should guess the line number from a colon" do
      pry_eval 'edit lib/pry.rb:10'
      expect(@line).to eq 10
    end

    it "should use the line number from -l" do
      pry_eval 'edit -l 10 lib/pry.rb'
      expect(@line).to eq 10
    end

    it "should not delete the file!" do
      pry_eval 'edit Rakefile'
      expect(File.exist?(@file)).to eq true
    end

    it "works with files that contain blanks in their names" do
      tf_path = File.join(File.dirname(@tf_path), 'swoop and doop.rb')
      FileUtils.touch(tf_path)
      pry_eval "edit #{tf_path}"
      expect(@file).to eq tf_path
      FileUtils.rm(tf_path)
    end

    if respond_to?(:require_relative, true)
      it "should work with require relative" do
        Pry.config.editor = lambda { |file, _line|
          File.open(file, 'w') { |f| f << 'require_relative "baz.rb"' }
          File.open(file.gsub('bar.rb', 'baz.rb'), 'w') do |f|
            f << "Pad.required = true; FileUtils.rm(__FILE__)"
          end
          nil
        }
        pry_eval "edit #{@tf_path}"
        expect(Pad.required).to eq true
      end
    end

    describe do
      before do
        Pad.counter = 0
        Pry.config.editor = lambda { |file, _line|
          File.open(file, 'w') { |f| f << "Pad.counter = Pad.counter + 1" }
          nil
        }
      end

      it "should reload the file if it is a ruby file" do
        temp_file do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit #{path}"

          expect(Pad.counter).to eq counter + 1
        end
      end

      it "should not reload the file if it is not a ruby file" do
        temp_file('.py') do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit #{path}"

          expect(Pad.counter).to eq counter
        end
      end

      it "should not reload a ruby file if -n is given" do
        temp_file do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit -n #{path}"

          expect(Pad.counter).to eq counter
        end
      end

      it "should reload a non-ruby file if -r is given" do
        temp_file('.pryrc') do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit -r #{path}"

          expect(Pad.counter).to eq counter + 1
        end
      end
    end

    describe do
      before do
        @reloading = nil
        Pry.config.editor = lambda do |file, line, reloading|
          @file = file
          @line = line
          @reloading = reloading
          nil
        end
      end

      it "should pass the editor a reloading arg" do
        pry_eval 'edit lib/pry.rb'
        expect(@reloading).to eq true
        pry_eval 'edit -n lib/pry.rb'
        expect(@reloading).to eq false
      end
    end
  end

  describe "with --ex" do
    before do
      @t = pry_tester do
        def last_exception=(exception)
          @pry.last_exception = exception
        end

        def last_exception
          @pry.last_exception
        end
      end
    end

    describe "with a real file" do
      before do
        @tf = Tempfile.new(["pry", ".rb"])
        @path = @tf.path
        @tf << "_foo = 1\n_bar = 2\nraise RuntimeError"
        @tf.flush

        begin
          load @path
        rescue RuntimeError => e
          @t.last_exception = e
        end
      end

      after do
        @tf.close(true)
      end

      it "should reload the file" do
        @t.pry.config.editor = lambda { |file, _line|
          File.open(file, 'w') { |f| f << "FOO = 'BAR'" }
          nil
        }

        expect(defined?(FOO)).to equal nil

        @t.eval 'edit --ex'

        expect(FOO).to eq 'BAR'
      end

      # regression test (this used to edit the current method instead
      # of the exception)
      it 'edits the exception even when in a patched method context' do
        source_location = nil
        Pry.config.editor = lambda { |file, line|
          source_location = [file, line]
          nil
        }

        Pad.le = @t.last_exception
        redirect_pry_io(InputTester.new("def broken_method", "binding.pry", "end",
                                        "broken_method",
                                        "pry_instance.last_exception = Pad.le",
                                        "edit --ex -n", "exit-all", "exit-all")) do
          Object.new.pry
        end

        expect(source_location).to contain_exactly(%r{(/private)?#{@path}}, 3)
        Pad.clear
      end

      it "should not reload the file if -n is passed" do
        Pry.config.editor = lambda { |file, _line|
          File.open(file, 'w') { |f| f << "FOO2 = 'BAZ'" }
          nil
        }

        expect(defined?(FOO2)).to equal nil

        @t.eval 'edit -n --ex'

        expect(defined?(FOO2)).to equal nil
      end

      describe "with --patch" do
        # Original source code must be untouched.
        it "should apply changes only in memory (monkey patching)" do
          @t.pry.config.editor = lambda { |file, _line|
            File.open(file, 'w') { |f| f << "FOO3 = 'PIYO'" }
            @patched_def = File.open(file, 'r').read
            nil
          }

          expect(defined?(FOO3)).to equal nil

          @t.eval 'edit --ex --patch'

          expect(FOO3).to eq 'PIYO'

          @tf.rewind
          expect(@tf.read).to eq "_foo = 1\n_bar = 2\nraise RuntimeError"
          expect(@patched_def).to eq "FOO3 = 'PIYO'"
        end
      end
    end

    describe "with --ex NUM" do
      before do
        @t.pry.config.editor = proc do |file, line|
          @__ex_file__ = file
          @__ex_line__ = line
          nil
        end

        @t.last_exception = mock_exception('a:1', 'b:2', 'c:3')
      end

      it 'should start on first level of backtrace with just --ex' do
        @t.eval 'edit -n --ex'
        expect(@__ex_file__).to eq "a"
        expect(@__ex_line__).to eq 1
      end

      it 'should start editor on first level of backtrace with --ex 0' do
        @t.eval 'edit -n --ex 0'
        expect(@__ex_file__).to eq "a"
        expect(@__ex_line__).to eq 1
      end

      it 'should start editor on second level of backtrace with --ex 1' do
        @t.eval 'edit -n --ex 1'
        expect(@__ex_file__).to eq "b"
        expect(@__ex_line__).to eq 2
      end

      it 'should start editor on third level of backtrace with --ex 2' do
        @t.eval 'edit -n --ex 2'
        expect(@__ex_file__).to eq "c"
        expect(@__ex_line__).to eq 3
      end

      it 'should display error message when backtrace level is invalid' do
        expect { @t.eval 'edit -n --ex 4' }.to raise_error Pry::CommandError
      end
    end
  end

  describe "without FILE" do
    before do
      @t = pry_tester
    end

    it "should edit the current expression if it's incomplete" do
      @t.push 'def a'
      @t.process_command 'edit'
      expect(@contents).to eq "def a\n"
    end

    it "should edit the previous expression if the current is empty" do
      @t.eval 'undef a if self.singleton_class.method_defined? :a'
      @t.eval 'def a; 2; end', 'edit'
      expect(@contents).to eq "def a; 2; end\n"
    end

    it "should use a blank file if -t is specified" do
      @t.eval 'undef a if self.singleton_class.method_defined? :a'
      @t.eval 'def a; 5; end', 'edit -t'
      expect(@contents).to eq "\n"
    end

    it "should use a blank file if -t given, even during an expression" do
      @t.push 'def a;'
      @t.process_command 'edit -t'
      expect(@contents).to eq "\n"
    end

    it "should position the cursor at the end of the expression" do
      @t.eval 'undef a if self.singleton_class.method_defined? :a'
      @t.eval "def a; 2;\nend"
      @t.process_command 'edit'
      expect(@line).to eq 2
    end

    it "should evaluate the expression" do
      @t.pry.config.editor = lambda { |file, _line|
        File.open(file, 'w') { |f| f << "'FOO'\n" }
        nil
      }
      @t.process_command 'edit'
      expect(@t.eval_string).to eq "'FOO'\n"
    end

    it "should ignore -n for tempfiles" do
      @t.pry.config.editor = lambda { |file, _line|
        File.open(file, 'w') { |f| f << "'FOO'\n" }
        nil
      }
      @t.process_command "edit -n"
      expect(@t.eval_string).to eq "'FOO'\n"
    end

    it "should not evaluate a file with -n" do
      @t.pry.config.editor = lambda { |file, _line|
        File.open(file, 'w') { |f| f << "'FOO'\n" }
        nil
      }
      begin
        @t.process_command 'edit -n spec/fixtures/foo.rb'
        expect(File.read("spec/fixtures/foo.rb")).to eq "'FOO'\n"
        expect(@t.eval_string).to eq ''
      ensure
        FileUtils.rm "spec/fixtures/foo.rb"
      end
    end

    it "should write the evaluated command to history" do
      quote = 'history repeats itself, first as tradegy...'
      @t.pry.config.editor = lambda { |file, _line|
        File.open(file, 'w') do |f|
          f << quote
        end
        nil
      }
      @t.process_command 'edit'
      expect(Pry.history.to_a.last).to eq quote
    end
  end

  describe "with --in" do
    it "should edit the nth line of _in_" do
      pry_eval '10', '11', 'edit --in -2'
      expect(@contents).to eq "10\n"
    end

    it "should edit the last line if no argument is given" do
      pry_eval '10', '11', 'edit --in'
      expect(@contents).to eq "11\n"
    end

    it "should edit a range of lines if a range is given" do
      pry_eval "10", "11", "edit -i 1,2"
      expect(@contents).to eq "10\n11\n"
    end

    it "should edit a multi-line expression as it occupies one line of _in_" do
      pry_eval "class #{1.class}\n  def invert; -self; end\nend", "edit -i 1"
      expect(@contents).to eq "class #{1.class}\n  def invert; -self; end\nend\n"
    end

    it "should not work with a filename" do
      expect { pry_eval 'edit ruby.rb -i' }.to raise_error(
        Pry::CommandError, /Only one of --ex, --temp, --in, --method and FILE/
      )
    end

    it "should not work with nonsense" do
      expect { pry_eval 'edit --in three' }.to raise_error(
        Pry::CommandError, /Not a valid range: three/
      )
    end
  end

  describe 'when editing a method by name' do
    def use_editor(tester, options)
      tester.pry.config.editor = lambda do |filename, _line|
        File.open(filename, 'w') { |f| f.write options.fetch(:replace_all) }
        nil
      end
      tester
    end

    # rubocop:disable Style/SingleLineMethods
    it 'uses patch editing on methods that were previously patched' do
      # initial definition
      tester   = pry_tester binding
      filename = __FILE__
      line     = __LINE__ + 2
      klass    = Class.new do
        def m; 1; end
      end
      expect(klass.new.m).to eq 1

      # now patch it
      use_editor(tester, replace_all: 'def m; 2; end').eval('edit --patch klass#m')
      expect(klass.new.m).to eq 2

      # edit by name, no --patch
      use_editor(tester, replace_all: 'def m; 3; end').eval("edit klass#m")
      expect(klass.new.m).to eq 3

      # original file is unchanged
      expect(File.readlines(filename)[line - 1].strip).to eq 'def m; 1; end'
    end
    # rubocop:enable Style/SingleLineMethods

    it 'can repeatedly edit methods that were defined in the console' do
      # initial definition
      tester = pry_tester binding
      tester.eval("klass = Class.new do\n"\
                  "  def m; 1; end\n"\
                  "end")
      expect(tester.eval("klass.new.m")).to eq 1

      # first edit
      use_editor(tester, replace_all: 'def m; 2; end').eval('edit klass#m')
      expect(tester.eval('klass.new.m')).to eq 2

      # repeat edit
      use_editor(tester, replace_all: 'def m; 3; end').eval('edit klass#m')
      expect(tester.eval('klass.new.m')).to eq 3
    end
  end

  describe "old edit-method tests now migrated to edit" do
    describe "on a method defined in a file" do
      before do
        Object.remove_const :X if defined? ::X
        Object.remove_const :A if defined? ::A
        @tempfile = Tempfile.new(['pry', '.rb'])
        @tempfile.puts(<<-CLASSES)
        module A
          def a
            :yup
          end

          def b
            :kinda
          end
        end

        class X
          include A

          def self.x
            :double_yup
          end

          def x
            :nope
          end

          def b
            super
          end
          alias c b

          def y?
            :because
          end

          class B
            G = :nawt

            def foo
              _foo = :possibly
              G
            end
          end
        end
        CLASSES
        @tempfile.flush
        load @tempfile.path

        @tempfile_path = @tempfile.path
      end

      after do
        @tempfile.close(true)
      end

      describe 'without -p' do
        before do
          @file = @line = @contents = nil
          Pry.config.editor = lambda do |file, line|
            @file = file
            @line = line
            nil
          end
        end

        # Workaround for https://github.com/jruby/jruby/issues/5436.
        let(:expected_file) { %r{(/private)?#{@tempfile_path}} }

        it "should correctly find a class method" do
          pry_eval 'edit X.x'
          expect(@file).to match(expected_file)
          expect(@line).to eq 14
        end

        it "should correctly find an instance method" do
          pry_eval 'edit X#x'
          expect(@file).to match(expected_file)
          expect(@line).to eq 18
        end

        it "should correctly find a method on an instance" do
          pry_eval 'x = X.new', 'edit x.x'
          expect(@file).to match(expected_file)
          expect(@line).to eq 18
        end

        it "should correctly find a method from a module" do
          pry_eval 'edit X#a'
          expect(@file).to match(expected_file)
          expect(@line).to eq 2
        end

        it "should correctly find an aliased method" do
          pry_eval 'edit X#c'
          expect(@file).to match(expected_file)
          expect(@line).to eq 22
        end
      end

      describe 'with -p' do
        before do
          Pry.config.editor = lambda do |file, _line|
            lines = File.read(file).lines.to_a
            lines[1] = if lines[2] =~ /end/
                         ":maybe\n"
                       else
                         "_foo = :maybe\n"
                       end
            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            @patched_def = String(lines[1]).chomp
            nil
          end
        end

        it "should successfully replace a class method" do
          pry_eval 'edit -p X.x'
          expect(X.method(:x).owner).to eq class << X; self end
          expect(X.method(:x).receiver).to eq X
          expect(X.x).to eq :maybe
        end

        it "should successfully replace an instance method" do
          pry_eval 'edit -p X#x'

          expect(X.instance_method(:x).owner).to eq X
          expect(X.new.x).to eq :maybe
        end

        it "should successfully replace a method on an instance" do
          pry_eval 'instance = X.new', 'edit -p instance.x'

          instance = X.new
          expect(instance.method(:x).owner).to eq X
          expect(instance.x).to eq :maybe
        end

        it "should successfully replace a method from a module" do
          pry_eval 'edit -p X#a'

          expect(X.instance_method(:a).owner).to eq A
          expect(X.new.a).to eq :maybe
        end

        it "should successfully replace a method with a question mark" do
          pry_eval 'edit -p X#y?'

          expect(X.instance_method(:y?).owner).to eq X
          expect(X.new.y?).to eq :maybe
        end

        it "should preserve module nesting" do
          pry_eval 'edit -p X::B#foo'

          expect(X::B.instance_method(:foo).owner).to eq X::B
          expect(X::B.new.foo).to eq :nawt
        end

        describe "monkey-patching" do
          before do
            @edit = 'edit --patch ' # A shortcut.
          end

          # @param [Integer] lineno
          # @return [String] the stripped line from the tempfile at +lineno+
          def stripped_line_at(lineno)
            @tempfile.rewind
            @tempfile.each_line.to_a[lineno].strip
          end

          # Applies the monkey patch for +method+ with help of evaluation of
          # +eval_strs+. The idea is to capture the initial line number (before
          # the monkey patch), because it gets overwritten by the line number from
          # the monkey patch. And our goal is to check that the original
          # definition hasn't changed.
          # @param [UnboundMethod] method
          # @param [Array<String>] eval_strs
          # @return [Array<String] the lines with definitions of the same line
          #   before monkey patching and after (normally, they should be equal)
          def apply_monkey_patch(method, *eval_strs)
            _, lineno = method.source_location
            definition_before = stripped_line_at(lineno)

            pry_eval(*eval_strs)

            definition_after = stripped_line_at(lineno)

            [definition_before, definition_after]
          end

          it "should work for a class method" do
            def_before, def_after =
              apply_monkey_patch(X.method(:x), "#{@edit} X.x")

            expect(def_before).to   eq ':double_yup'
            expect(def_after).to    eq ':double_yup'
            expect(@patched_def).to eq ':maybe'
          end

          it "should work for an instance method" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:x), "#{@edit} X#x")

            expect(def_before).to   eq ':nope'
            expect(def_after).to    eq ':nope'
            expect(@patched_def).to eq ':maybe'
          end

          it "should work for a method on an instance" do
            def_before, def_after = apply_monkey_patch(
              X.instance_method(:x), 'instance = X.new', "#{@edit} instance.x"
            )

            expect(def_before).to   eq ':nope'
            expect(def_after).to    eq ':nope'
            expect(@patched_def).to eq ':maybe'
          end

          it "should work for a method from a module" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:a), "#{@edit} X#a")

            expect(def_before).to   eq ':yup'
            expect(def_after).to    eq ':yup'
            expect(@patched_def).to eq ':maybe'
          end

          it "should work for a method with a question mark" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:y?), "#{@edit} X#y?")

            expect(def_before).to   eq ':because'
            expect(def_after).to    eq ':because'
            expect(@patched_def).to eq ':maybe'
          end

          it "should work with nesting" do
            def_before, def_after =
              apply_monkey_patch(X::B.instance_method(:foo), "#{@edit} X::B#foo")

            expect(def_before).to   eq '_foo = :possibly'
            expect(def_after).to    eq '_foo = :possibly'
            expect(@patched_def).to eq '_foo = :maybe'
          end
        end
      end

      describe 'on an aliased method' do
        before do
          Pry.config.editor = lambda do |file, _line|
            lines = File.read(file).lines.to_a

            # rubocop:disable Lint/InterpolationCheck
            lines[1] = '"#{super}aa".to_sym' + "\n"
            # rubocop:enable Lint/InterpolationCheck

            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            nil
          end
        end

        it "should change the alias, but not the original, without breaking super" do
          pry_eval 'edit -p X#c'

          expect(Pry::Method.from_str("X#c").alias?).to eq true
          expect(X.new.b).to eq :kinda
          expect(X.new.c).to eq :kindaaa
        end
      end

      describe 'with three-arg editor' do
        before do
          @file = @line = @reloading = nil
          Pry.config.editor = lambda do |file, line, reloading|
            @file = file
            @line = line
            @reloading = reloading
            nil
          end
        end

        it "should pass the editor a reloading arg" do
          pry_eval 'edit X.x'
          expect(@reloading).to eq true
          pry_eval 'edit -n X.x'
          expect(@reloading).to eq false
        end
      end
    end
  end

  describe "--method flag" do
    before do
      @t = pry_tester
      class BinkyWink
        # rubocop:disable Style/EvalWithLocation
        eval <<-RUBY
          def m1
            binding
          end
        RUBY
        # rubocop:enable Style/EvalWithLocation

        def m2
          _foo = :jeremy_jones
          binding
        end
      end
    end

    after do
      Object.remove_const(:BinkyWink)
    end

    it 'should edit method context' do
      Pry.config.editor = lambda do |file, line|
        expect([file, line]).to eq BinkyWink.instance_method(:m2).source_location
        nil
      end

      t = pry_tester(BinkyWink.new.m2)
      t.process_command "edit -m -n"
    end

    it 'errors when cannot find method context' do
      Pry.config.editor = lambda do |file, line|
        expect([file, line]).to eq BinkyWink.instance_method(:m1).source_location
        nil
      end

      t = pry_tester(BinkyWink.new.m1)
      expect { t.process_command "edit -m -n" }
        .to raise_error(Pry::CommandError, /Cannot find a file for/)
    end

    it 'errors when a filename arg is passed with --method' do
      expect { @t.process_command "edit -m Pry#repl" }
        .to raise_error(Pry::CommandError, /Only one of/)
    end
  end

  describe "pretty error messages" do
    before do
      @t = pry_tester
      class TrinkyDink
        # rubocop:disable Style/EvalWithLocation
        eval('def m; end')
        # rubocop:enable Style/EvalWithLocation
      end
    end

    after do
      Object.remove_const(:TrinkyDink)
    end

    it 'should display a nice error message when cannot open a file' do
      expect { @t.process_command "edit TrinkyDink#m" }
        .to raise_error(Pry::CommandError, /Cannot find a file for/)
    end
  end
end
