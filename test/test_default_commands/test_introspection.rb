require 'helper'

describe "Pry::DefaultCommands::Introspection" do
  describe "edit" do
    before do
      @old_editor = Pry.config.editor
      @file = nil; @line = nil; @contents = nil
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
        mock_pry("edit foo.rb")
        @file.should == File.expand_path("foo.rb")
        mock_pry("edit /tmp/bar.rb")
        @file.should == "/tmp/bar.rb"
      end

      it "should guess the line number from a colon" do
        mock_pry("edit /tmp/foo.rb:10")
        @line.should == 10
      end

      it "should use the line number from -l" do
        mock_pry("edit -l 10 /tmp/foo.rb")
        @line.should == 10
      end

      it "should not delete the file!" do
        mock_pry("edit Rakefile")
        File.exist?(@file).should == true
      end

      describe do
        before do
          @rand = rand
          Pry.config.editor = lambda { |file, line|
            File.open(file, 'w') { |f| f << "$rand = #{@rand.inspect}" }
            nil
          }
        end

        it "should reload the file if it is a ruby file" do
          tf = Tempfile.new(["pry", ".rb"])
          path = tf.path

          mock_pry("edit #{path}", "$rand").should =~ /#{@rand}/

          tf.close(true)
        end

        it "should not reload the file if it is not a ruby file" do
          tf = Tempfile.new(["pry", ".py"])
          path = tf.path

          mock_pry("edit #{path}", "$rand").should.not =~ /#{@rand}/

          tf.close(true)
        end

        it "should not reload a ruby file if -n is given" do
          tf = Tempfile.new(["pry", ".rb"])
          path = tf.path

          mock_pry("edit -n #{path}", "$rand").should.not =~ /#{@rand}/

          tf.close(true)
        end

        it "should reload a non-ruby file if -r is given" do
          tf = Tempfile.new(["pry", ".pryrc"])
          path = tf.path

          mock_pry("edit -r #{path}", "$rand").should =~ /#{@rand}/

          tf.close(true)
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
          mock_pry("edit foo.rb")
          @reloading.should == true
          mock_pry("edit -n foo.rb")
          @reloading.should == false
        end
      end
    end

    describe "with --ex" do
      before do
        @tf = Tempfile.new(["pry", ".rb"])
        @path = @tf.path
        @tf << "1\n2\nraise RuntimeError"
        @tf.flush
      end
      after do
        @tf.close(true)
        File.unlink("#{@path}c") if File.exists?("#{@path}c") #rbx
      end
      it "should open the correct file" do
        mock_pry("require #{@path.inspect}", "edit --ex")

        @file.should == @path
        @line.should == 3
      end

      it "should reload the file" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "FOO = 'BAR'" }
          nil
        }

        mock_pry("require #{@path.inspect}", "edit --ex", "FOO").should =~ /BAR/
      end

      it "should not reload the file if -n is passed" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "FOO2 = 'BAZ'" }
          nil
        }

        mock_pry("require #{@path.inspect}", "edit -n --ex", "FOO2").should.not =~ /BAZ/
      end
    end

    describe "with --ex NUM" do
      before do
        Pry.config.editor = proc do |file, line|
          @__ex_file__ = file
          @__ex_line__ = line
          nil
        end
      end

      it 'should start editor on first level of backtrace when --ex used with no argument ' do
        pry_instance = Pry.new(:input => StringIO.new("edit -n --ex"), :output => StringIO.new)
        pry_instance.last_exception = mock_exception("a:1", "b:2", "c:3")
        pry_instance.rep(self)
        @__ex_file__.should == "a"
        @__ex_line__.should == 1
      end

      it 'should start editor on first level of backtrace when --ex 0 used ' do
        pry_instance = Pry.new(:input => StringIO.new("edit -n --ex 0"), :output => StringIO.new)
        pry_instance.last_exception = mock_exception("a:1", "b:2", "c:3")
        pry_instance.rep(self)
        @__ex_file__.should == "a"
        @__ex_line__.should == 1
      end

      it 'should start editor on second level of backtrace when --ex 1 used' do
        pry_instance = Pry.new(:input => StringIO.new("edit -n --ex 1"), :output => StringIO.new)
        pry_instance.last_exception = mock_exception("a:1", "b:2", "c:3")
        pry_instance.rep(self)
        @__ex_file__.should == "b"
        @__ex_line__.should == 2
      end

      it 'should start editor on third level of backtrace when --ex 2 used' do
        pry_instance = Pry.new(:input => StringIO.new("edit -n --ex 2"), :output => StringIO.new)
        pry_instance.last_exception = mock_exception("a:1", "b:2", "c:3")
        pry_instance.rep(self)
        @__ex_file__.should == "c"
        @__ex_line__.should == 3
      end

      it 'should display error message when backtrace level is out of bounds (using --ex 4)' do
        pry_instance = Pry.new(:input => StringIO.new("edit -n --ex 4"), :output => str_output = StringIO.new)
        pry_instance.last_exception = mock_exception("a:1", "b:2", "c:3")
        pry_instance.rep(self)
        str_output.string.should =~ /Exception has no associated file/
      end
    end

    describe "without FILE" do
      it "should edit the current expression if it's incomplete" do
        mock_pry("def a", "edit")
        @contents.should == "def a\n"
      end

      it "should edit the previous expression if the current is empty" do
        mock_pry("def a; 2; end", "edit")
        @contents.should == "def a; 2; end\n"
      end

      it "should use a blank file if -t is specified" do
        mock_pry("def a; 5; end", "edit -t")
        @contents.should == "\n"
      end

      it "should use a blank file if -t is specified even half-way through an expression" do
        mock_pry("def a;", "edit -t")
        @contents.should == "\n"
      end

      it "should position the cursor at the end of the expression" do
        mock_pry("def a; 2;"," end", "edit")
        @line.should == 2
      end

      it "should evaluate the expression" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "'FOO'\n" }
          nil
        }
        mock_pry("edit").should =~ /FOO/
      end
      it "should not evaluate the expression with -n" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "'FOO'\n" }
          nil
        }
        mock_pry("edit -n").should.not =~ /FOO/
      end
    end

    describe "with --in" do
      it "should edit the nth line of _in_" do
        mock_pry("10", "11", "edit --in -2")
        @contents.should == "10\n"
      end

      it "should edit the last line if no argument is given" do
        mock_pry("10", "11", "edit --in")
        @contents.should == "11\n"
      end

      it "should edit a range of lines if a range is given" do
        mock_pry("10", "11", "edit -i 1,2")
        @contents.should == "10\n11\n"
      end

      it "should edit a multi-line expression as it occupies one line of _in_" do
        mock_pry("class Fixnum", "  def invert; -self; end", "end", "edit -i 1")
        @contents.should == "class Fixnum\n  def invert; -self; end\nend\n"
      end

      it "should not work with a filename" do
        mock_pry("edit ruby.rb -i").should =~ /Only one of --ex, --temp, --in and FILE may be specified/
      end

      it "should not work with nonsense" do
        mock_pry("edit --in three").should =~ /Not a valid range: three/
      end
    end
  end

  describe "edit-method" do
    describe "on a method defined in a file" do
      before do
        @tempfile = Tempfile.new(['pry', '*.rb'])
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
          end
        EOS
        @tempfile.flush
        load @tempfile.path
      end

      after do
        @tempfile.close(true)
      end

      describe 'without -p' do
        before do
          @old_editor = Pry.config.editor
          @file, @line, @contents = nil, nil, nil
          Pry.config.editor = lambda do |file, line|
            @file = file; @line = line
            nil
          end
        end
        after do
          Pry.config.editor = @old_editor
        end

        it "should correctly find a class method" do
          mock_pry("edit-method X.x")
          @file.should == @tempfile.path
          @line.should == 14
        end

        it "should correctly find an instance method" do
          mock_pry("edit-method X#x")
          @file.should == @tempfile.path
          @line.should == 18
        end

        it "should correctly find a method on an instance" do
          mock_pry("x = X.new", "edit-method x.x")
          @file.should == @tempfile.path
          @line.should == 18
        end

        it "should correctly find a method from a module" do
          mock_pry("edit-method X#a")
          @file.should == @tempfile.path
          @line.should == 2
        end

        it "should correctly find an aliased method" do
          mock_pry("edit-method X#c")
          @file.should == @tempfile.path
          @line.should == 22
        end
      end

      describe 'with -p' do
        before do
          @old_editor = Pry.config.editor
          Pry.config.editor = lambda do |file, line|
            lines = File.read(file).lines.to_a
            lines[1] = ":maybe\n"
            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            nil
          end
        end
        after do
          Pry.config.editor = @old_editor
        end

        it "should successfully replace a class method" do
          mock_pry("edit-method -p X.x")

          class << X
            X.method(:x).owner.should == self
          end
          X.method(:x).receiver.should == X
          X.x.should == :maybe
        end

        it "should successfully replace an instance method" do
          mock_pry("edit-method -p X#x")

          X.instance_method(:x).owner.should == X
          X.new.x.should == :maybe
        end

        it "should successfully replace a method on an instance" do
          mock_pry("instance = X.new", "edit-method -p instance.x")

          instance = X.new
          instance.method(:x).owner.should == X
          instance.x.should == :maybe
        end

        it "should successfully replace a method from a module" do
          mock_pry("edit-method -p X#a")

          X.instance_method(:a).owner.should == A
          X.new.a.should == :maybe
        end

        it "should successfully replace a method with a question mark" do
          mock_pry("edit-method -p X#y?")

          X.instance_method(:y?).owner.should == X
          X.new.y?.should == :maybe
        end
      end

      describe 'on an aliased method' do
        before do
          @old_editor = Pry.config.editor
          Pry.config.editor = lambda do |file, line|
            lines = File.read(file).lines.to_a
            lines[1] = '"#{super}aa".to_sym' + "\n"
            File.open(file, 'w') do |f|
              f.write(lines.join)
            end
            nil
          end
        end
        after do
          Pry.config.editor = @old_editor
        end

        it "should change the alias, but not the original, without breaking super" do
          mock_pry("edit-method -p X#c")

          Pry::Method.from_str("X#c").alias?.should == true

          X.new.b.should == :kinda
          X.new.c.should == :kindaaa
        end
      end

      describe 'with three-arg editor' do
        before do
          @old_editor = Pry.config.editor
          @file, @line, @reloading = nil, nil, nil
          Pry.config.editor = lambda do |file, line, reloading|
            @file = file; @line = line; @reloading = reloading
            nil
          end
        end
        after do
          Pry.config.editor = @old_editor
        end

        it "should pass the editor a reloading arg" do
          mock_pry('edit-method X.x')
          @reloading.should == true
          mock_pry('edit-method -n X.x')
          @reloading.should == false
        end
      end

    end
  end

  # show-command only works in implementations that support Proc#source_location
  if Proc.method_defined?(:source_location)
    describe "show-command" do
      before do
        @str_output = StringIO.new
      end

      it 'should show source for an ordinary command' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo" do
            :body_of_foo
          end
        end

        redirect_pry_io(InputTester.new("show-command foo"), @str_output) do
          Pry.new(:commands => set).rep
        end

        @str_output.string.should =~ /:body_of_foo/
      end

      it 'should show source for a command with spaces in its name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo bar" do
            :body_of_foo_bar
          end
        end

        redirect_pry_io(InputTester.new("show-command \"foo bar\""), @str_output) do
          Pry.new(:commands => set).rep
        end

        @str_output.string.should =~ /:body_of_foo_bar/
      end

      it 'should show source for a command by listing name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command /foo(.*)/, "", :listing => "bar" do
            :body_of_foo_regex
          end
        end

        redirect_pry_io(InputTester.new("show-command bar"), @str_output) do
          Pry.new(:commands => set).rep
        end

        @str_output.string.should =~ /:body_of_foo_regex/
      end
    end
  end
end
