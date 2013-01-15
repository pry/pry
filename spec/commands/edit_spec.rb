require 'pathname'
require 'helper'

describe "edit" do
  before do
    @old_editor = Pry.config.editor
    @file = @line = @contents = nil
    Pry.config.editor = lambda do |file, line|
      @file = file; @line = line; @contents = File.read(@file)
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
        if Pry::Helpers::BaseHelpers.mri_19?
          Pathname.new(Dir::Tmpname.tmpdir)
        else
          Pathname.new(Dir.tmpdir)
        end

      @tf_path = File.expand_path(File.join(@tf_dir.to_s, 'bar.rb'))
      FileUtils.touch(@tf_path)
    end

    after do
      FileUtils.rm(@tf_path) if File.exists?(@tf_path)
    end

    it "should invoke Pry.config.editor with absolutified filenames" do
      pry_eval 'edit lib/pry.rb'
      @file.should == File.expand_path('lib/pry.rb')

      pry_eval "edit #@tf_path"
      @file.should == @tf_path
    end

    it "should guess the line number from a colon" do
      pry_eval 'edit lib/pry.rb:10'
      @line.should == 10
    end

    it "should use the line number from -l" do
      pry_eval 'edit -l 10 lib/pry.rb'
      @line.should == 10
    end

    it "should not delete the file!" do
      pry_eval 'edit Rakefile'
      File.exist?(@file).should == true
    end

    it "works with files that contain blanks in their names" do
      tf_path = File.join(File.dirname(@tf_path), 'swoop and doop.rb')
      FileUtils.touch(tf_path)
      pry_eval "edit #{ tf_path }"
      @file.should == tf_path
      FileUtils.rm(tf_path)
    end

    describe do
      before do
        Pad.counter = 0
        Pry.config.editor = lambda { |file, line|
          File.open(file, 'w') { |f| f << "Pad.counter = Pad.counter + 1" }
          nil
        }
      end

      it "should reload the file if it is a ruby file" do
        temp_file do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit #{path}"

          Pad.counter.should == counter + 1
        end
      end

      it "should not reload the file if it is not a ruby file" do
        temp_file('.py') do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit #{path}"

          Pad.counter.should == counter
        end
      end

      it "should not reload a ruby file if -n is given" do
        temp_file do |tf|
          counter = Pad.counter
          path    = tf.path

          Pad.counter.should == counter
        end
      end

      it "should reload a non-ruby file if -r is given" do
        temp_file('.pryrc') do |tf|
          counter = Pad.counter
          path    = tf.path

          pry_eval "edit -r #{path}"

          Pad.counter.should == counter + 1
        end
      end
    end

    describe do
      before do
        @reloading = nil
        Pry.config.editor = lambda do |file, line, reloading|
          @file = file; @line = line; @reloading = reloading
          nil
        end
      end

      it "should pass the editor a reloading arg" do
        pry_eval 'edit lib/pry.rb'
        @reloading.should == true
        pry_eval 'edit -n lib/pry.rb'
        @reloading.should == false
      end
    end
  end

  describe "with --ex" do
    before do
      @t = pry_tester do
        def last_exception=(exception)
          @pry.last_exception = exception
        end
        def last_exception; @pry.last_exception; end
      end
    end

    describe "with a real file" do
      before do
        @tf = Tempfile.new(["pry", ".rb"])
        @path = @tf.path
        @tf << "1\n2\nraise RuntimeError"
        @tf.flush

        begin
          load @path
        rescue RuntimeError => e
          @t.last_exception = e
        end
      end

      after do
        @tf.close(true)
        File.unlink("#{@path}c") if File.exists?("#{@path}c") #rbx
      end

      it "should reload the file" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "FOO = 'BAR'" }
          nil
        }

        defined?(FOO).should.be.nil

        @t.eval 'edit --ex'

        FOO.should == 'BAR'
      end

      # regression test (this used to edit the current method instead
      # of the exception)
      it 'edits the exception even when in a patched method context' do
        source_location = nil
        Pry.config.editor = lambda {|file, line|
          source_location = [file, line]
          nil
        }

        Pad.le = @t.last_exception
        redirect_pry_io(InputTester.new("def broken_method", "binding.pry", "end",
                                        "broken_method",
                                        "_pry_.last_exception = Pad.le",
                                        "edit --ex -n", "exit-all", "exit-all")) do
          Object.new.pry
        end

        source_location.should == [@path, 3]
        Pad.clear
      end

      it "should not reload the file if -n is passed" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "FOO2 = 'BAZ'" }
          nil
        }

        defined?(FOO2).should.be.nil

        @t.eval 'edit -n --ex'

        defined?(FOO2).should.be.nil
      end

      describe "with --patch" do
        # Original source code must be untouched.
        it "should apply changes only in memory (monkey patching)" do
          Pry.config.editor = lambda {|file, line|
            File.open(file, 'w'){|f| f << "FOO3 = 'PIYO'" }
            @patched_def = File.open(file, 'r').read
            nil
          }

          defined?(FOO3).should.be.nil

          @t.eval 'edit --ex --patch'

          FOO3.should == 'PIYO'

          @tf.rewind
          @tf.read.should == "1\n2\nraise RuntimeError"
          @patched_def.should == "FOO3 = 'PIYO'"
        end
      end
    end

    describe "with --ex NUM" do
      before do
        Pry.config.editor = proc do |file, line|
          @__ex_file__ = file
          @__ex_line__ = line
          nil
        end

        @t.last_exception = mock_exception('a:1', 'b:2', 'c:3')
      end

      it 'should start on first level of backtrace with just --ex' do
        @t.eval 'edit -n --ex'
        @__ex_file__.should == "a"
        @__ex_line__.should == 1
      end

      it 'should start editor on first level of backtrace with --ex 0' do
        @t.eval 'edit -n --ex 0'
        @__ex_file__.should == "a"
        @__ex_line__.should == 1
      end

      it 'should start editor on second level of backtrace with --ex 1' do
        @t.eval 'edit -n --ex 1'
        @__ex_file__.should == "b"
        @__ex_line__.should == 2
      end

      it 'should start editor on third level of backtrace with --ex 2' do
        @t.eval 'edit -n --ex 2'
        @__ex_file__.should == "c"
        @__ex_line__.should == 3
      end

      it 'should display error message when backtrace level is invalid' do
        proc {
          @t.eval 'edit -n --ex 4'
        }.should.raise(Pry::CommandError)
      end
    end
  end

  describe "without FILE" do
    before do
      @t = pry_tester
    end

    it "should edit the current expression if it's incomplete" do
      eval_str = 'def a'
      @t.process_command 'edit', eval_str
      @contents.should == "def a\n"
    end

    it "should edit the previous expression if the current is empty" do
      @t.eval 'def a; 2; end', 'edit'
      @contents.should == "def a; 2; end\n"
    end

    it "should use a blank file if -t is specified" do
      @t.eval 'def a; 5; end', 'edit -t'
      @contents.should == "\n"
    end

    it "should use a blank file if -t given, even during an expression" do
      eval_str = 'def a;'
      @t.process_command 'edit -t', eval_str
      @contents.should == "\n"
    end

    it "should position the cursor at the end of the expression" do
      eval_str = "def a; 2;\nend"
      @t.process_command 'edit', eval_str
      @line.should == 2
    end

    it "should evaluate the expression" do
      Pry.config.editor = lambda {|file, line|
        File.open(file, 'w'){|f| f << "'FOO'\n" }
        nil
      }
      eval_str = ''
      @t.process_command 'edit', eval_str
      eval_str.should == "'FOO'\n"
    end

    it "should not evaluate the expression with -n" do
      Pry.config.editor = lambda {|file, line|
        File.open(file, 'w'){|f| f << "'FOO'\n" }
        nil
      }
      eval_str = ''
      @t.process_command 'edit -n', eval_str
      eval_str.should == ''
    end
  end

  describe "with --in" do
    it "should edit the nth line of _in_" do
      pry_eval '10', '11', 'edit --in -2'
      @contents.should == "10\n"
    end

    it "should edit the last line if no argument is given" do
      pry_eval '10', '11', 'edit --in'
      @contents.should == "11\n"
    end

    it "should edit a range of lines if a range is given" do
      pry_eval "10", "11", "edit -i 1,2"
      @contents.should == "10\n11\n"
    end

    it "should edit a multi-line expression as it occupies one line of _in_" do
      pry_eval "class Fixnum\n  def invert; -self; end\nend", "edit -i 1"
      @contents.should == "class Fixnum\n  def invert; -self; end\nend\n"
    end

    it "should not work with a filename" do
      proc {
        pry_eval 'edit ruby.rb -i'
      }.should.raise(Pry::CommandError).
        message.should =~ /Only one of --ex, --temp, --in, --method and FILE/
    end

    it "should not work with nonsense" do
      proc {
        pry_eval 'edit --in three'
      }.should.raise(Pry::CommandError).
        message.should =~ /Not a valid range: three/
    end
  end

  describe "old edit-method tests now migrated to edit" do
    describe "on a method defined in a file" do
      before do
        @tempfile = (Tempfile.new(['pry', '.rb']))
        @tempfile.puts <<-EOS
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
              :possibly
              G
            end
          end
        end
        EOS
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
            @file = file; @line = line
            nil
          end
        end

        it "should correctly find a class method" do
          pry_eval 'edit X.x'

          @file.should == @tempfile_path
          @line.should == 14

        end

        it "should correctly find an instance method" do
          pry_eval 'edit X#x'
          @file.should == @tempfile_path
          @line.should == 18
        end

        it "should correctly find a method on an instance" do
          pry_eval 'x = X.new', 'edit x.x'
          @file.should == @tempfile_path
          @line.should == 18
        end

        it "should correctly find a method from a module" do
          pry_eval 'edit X#a'
          @file.should == @tempfile_path
          @line.should == 2
        end

        it "should correctly find an aliased method" do
          pry_eval 'edit X#c'
          @file.should == @tempfile_path
          @line.should == 22
        end
      end

      describe 'with -p' do
        before do
          Pry.config.editor = lambda do |file, line|
            lines = File.read(file).lines.to_a
            lines[1] = ":maybe\n"
            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            @patched_def = String(lines[1]).chomp
            nil
          end
        end

        it "should successfully replace a class method" do
          pry_eval 'edit -p X.x'

          class << X
            X.method(:x).owner.should == self
          end
          X.method(:x).receiver.should == X
          X.x.should == :maybe
        end

        it "should successfully replace an instance method" do
          pry_eval 'edit -p X#x'

          X.instance_method(:x).owner.should == X
          X.new.x.should == :maybe
        end

        it "should successfully replace a method on an instance" do
          pry_eval 'instance = X.new', 'edit -p instance.x'

          instance = X.new
          instance.method(:x).owner.should == X
          instance.x.should == :maybe
        end

        it "should successfully replace a method from a module" do
          pry_eval 'edit -p X#a'

          X.instance_method(:a).owner.should == A
          X.new.a.should == :maybe
        end

        it "should successfully replace a method with a question mark" do
          pry_eval 'edit -p X#y?'

          X.instance_method(:y?).owner.should == X
          X.new.y?.should == :maybe
        end

        it "should preserve module nesting" do
          pry_eval 'edit -p X::B#foo'

          X::B.instance_method(:foo).owner.should == X::B
          X::B.new.foo.should == :nawt
        end

        describe "monkey-patching" do
          before do
            @edit = 'edit --patch ' # A shortcut.
          end

          # @param [Integer] lineno
          # @return [String] the stripped line from the tempfile at +lineno+
          def stripped_line_at(lineno)
            @tempfile.rewind
            @tempfile.lines.to_a[lineno].strip
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
              apply_monkey_patch(X.method(:x), "#@edit X.x")

            def_before.should   == ':double_yup'
            def_after.should    == ':double_yup'
            @patched_def.should == ':maybe'
          end

          it "should work for an instance method" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:x), "#@edit X#x")

            def_before.should   == ':nope'
            def_after.should    == ':nope'
            @patched_def.should == ':maybe'
          end

          it "should work for a method on an instance" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:x), 'instance = X.new', "#@edit instance.x")

            def_before.should   == ':nope'
            def_after.should    == ':nope'
            @patched_def.should == ':maybe'
          end

          it "should work for a method from a module" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:a), "#@edit X#a")

            def_before.should   == ':yup'
            def_after.should    == ':yup'
            @patched_def.should == ':maybe'
          end

          it "should work for a method with a question mark" do
            def_before, def_after =
              apply_monkey_patch(X.instance_method(:y?), "#@edit X#y?")

            def_before.should   == ':because'
            def_after.should    == ':because'
            @patched_def.should == ':maybe'
          end

          it "should work with nesting" do
            def_before, def_after =
              apply_monkey_patch(X::B.instance_method(:foo), "#@edit X::B#foo")

            def_before.should   == ':possibly'
            def_after.should    == ':possibly'
            @patched_def.should == ':maybe'
          end
        end
      end

      describe 'on an aliased method' do
        before do
          Pry.config.editor = lambda do |file, line|
            lines = File.read(file).lines.to_a
            lines[1] = '"#{super}aa".to_sym' + "\n"
            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            nil
          end
        end

        it "should change the alias, but not the original, without breaking super" do

          $x = :bebe
          pry_eval 'edit -p X#c'


          Pry::Method.from_str("X#c").alias?.should == true

          X.new.b.should == :kinda
          X.new.c.should == :kindaaa
          $x = nil
        end
      end

      describe 'with three-arg editor' do
        before do
          @file = @line = @reloading = nil
          Pry.config.editor = lambda do |file, line, reloading|
            @file = file; @line = line; @reloading = reloading
            nil
          end
        end

        it "should pass the editor a reloading arg" do
          pry_eval 'edit X.x'
          @reloading.should == true
          pry_eval 'edit -n X.x'
          @reloading.should == false
        end
      end
    end
  end

  describe "--method flag" do
    before do
      @t = pry_tester
      class BinkyWink
        eval %{
          def tits_macgee
            binding
          end
        }

        def tots_macgee
          :jeremy_jones
          binding
        end
      end
    end

    after do
      Object.remove_const(:BinkyWink)
    end

    it 'should edit method context' do
      Pry.editor = lambda do |file, line|
        [file, line].should == BinkyWink.instance_method(:tots_macgee).source_location
        nil
      end

      t = pry_tester(BinkyWink.new.tots_macgee)
      t.process_command "edit -m -n"
    end

    it 'errors when cannot find method context' do
      Pry.editor = lambda do |file, line|
        [file, line].should == BinkyWink.instance_method(:tits_macgee).source_location
        nil
      end

      t = pry_tester(BinkyWink.new.tits_macgee)
      lambda { t.process_command "edit -m -n" }.should.
        raise(Pry::CommandError).message.should.match(/Cannot find a file for/)
    end

    it 'errors when a filename arg is passed with --method' do
      lambda { @t.process_command "edit -m Pry#repl" }.should.
        raise(Pry::CommandError).message.should.match(/Only one of/)
    end
  end

  describe "pretty error messages" do
    before do
      @t = pry_tester
      class TrinkyDink
        eval %{
          def claudia_linklater
          end
        }
      end
    end

    after do
      Object.remove_const(:TrinkyDink)
    end

    it 'should display a nice error message when cannot open a file' do
      lambda { @t.process_command "edit TrinkyDink#claudia_linklater" }.should.
        raise(Pry::CommandError).message.should.match(/Cannot find a file for/)
    end
  end
end
