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

  describe "show-method" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output help' do
      mock_pry('show-method -h').should =~ /Usage: show-method/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method -l sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source with line numbers starting at 1' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method -b sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /1: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method", "exit-all"), $str_output) do
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
        redirect_pry_io(InputTester.new("show-method -l", "exit-all"), $str_output) do
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
      redirect_pry_io(InputTester.new("show-method o.foo('bar', 'baz bam').foo", "exit-all"), str_output) do
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

      mock_pry(binding, "show-method c.new.method").should =~ /98/
    end

    it "should find instance_methods even if the class has an override instance_method method" do
      c = Class.new{
        def method;
          98
        end

        def self.instance_method; 789; end
      }

      mock_pry(binding, "show-method c#method").should =~ /98/

    end

    it "should find instance methods with -M" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c","show-method -M moo").should =~ /ve over/
    end

    it "should not find instance methods with -m" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-method -m moo").should =~ /could not be found/
    end

    it "should find normal methods with -m" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-method -m moo").should =~ /ve over/
    end

    it "should not find normal methods with -M" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-method -M moo").should =~ /could not be found/
    end

    it "should find normal methods with no -M or -m" do
      c = Class.new{ def self.moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-method moo").should =~ /ve over/
    end

    it "should find instance methods with no -M or -m" do
      c = Class.new{ def moo; "ve over!"; end }
      mock_pry(binding, "cd c", "show-method moo").should =~ /ve over/
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

      mock_pry(binding, "show-method --super o.foo").should =~ /:super_wibble/

    end

    it "should not raise an exception when a non-extant super method is requested" do
      o = Object.new
      def o.foo(*bars); end

      mock_pry(binding, "show-method --super o.foo").should =~ /'self.foo' has no super method/
    end

    # dynamically defined method source retrieval is only supported in
    # 1.9 - where Method#source_location is native
    if RUBY_VERSION =~ /1.9/
      it 'should output a method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("def dyna_method", ":testing", "end", "show-method dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output a method\'s source for a method defined inside pry, even if exceptions raised before hand' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("bad code", "123", "bad code 2", "1 + 2", "def dyna_method", ":testing", "end", "show-method dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output an instance method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "def yo", "end", "end", "show-method A#yo"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def yo/
        Object.remove_const :A
      end

      it 'should output an instance method\'s source for a method defined inside pry using define_method' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "define_method(:yup) {}", "end", "show-method A#yup"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /define_method\(:yup\)/
        Object.remove_const :A
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
    end
  end

  # show-command only works in implementations that support Proc#source_location
  if Proc.method_defined?(:source_location)
    describe "show-command" do
      it 'should show source for an ordinary command' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo" do
            :body_of_foo
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command foo"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo/
      end

      it 'should show source for a command with spaces in its name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo bar" do
            :body_of_foo_bar
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command \"foo bar\""), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_bar/
      end

      it 'should show source for a command by listing name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command /foo(.*)/, "", :listing => "bar" do
            :body_of_foo_regex
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command bar"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_regex/
      end
    end
  end


end
