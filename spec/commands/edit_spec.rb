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
    it "should invoke Pry.config.editor with absolutified filenames" do
      pry_eval 'edit lib/pry.rb'
      @file.should == File.expand_path('lib/pry.rb')

      FileUtils.touch '/tmp/bar.rb'
      pry_eval 'edit /tmp/bar.rb'
      @file.should == '/tmp/bar.rb'
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
          message.should =~ /Only one of --ex, --temp, --in and FILE/
    end

    it "should not work with nonsense" do
      proc {
        pry_eval 'edit --in three'
      }.should.raise(Pry::CommandError).
          message.should =~ /Not a valid range: three/
    end
  end
end
