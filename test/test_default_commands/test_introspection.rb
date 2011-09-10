require 'helper'

describe "Pry::DefaultCommands::Introspection" do

  describe "edit" do
    before do
      @old_editor = Pry.config.editor
      @file = nil; @line = nil; @contents = nil
      Pry.config.editor = lambda do |file, line|
        @file = file; @line = line; @contents = File.read(@file)
        ":" # The : command does nothing.
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
            ":"
          }
        end

        it "should reload the file if it is a ruby file" do
          path = Tempfile.new(["tmp", ".rb"]).path

          mock_pry("edit #{path}", "$rand").should =~ /#{@rand}/

          File.unlink(path)
        end

        it "should not reload the file if it is not a ruby file" do
          path = Tempfile.new(["tmp", ".py"]).path

          mock_pry("edit #{path}", "$rand").should.not =~ /#{@rand}/

          File.unlink(path)
        end

        it "should not reload a ruby file if -n is given" do
          path = Tempfile.new(["tmp", ".rb"]).path

          mock_pry("edit -n #{path}", "$rand").should.not =~ /#{@rand}/

          File.unlink(path)
        end

        it "should reload a non-ruby file if -r is given" do
          path = Tempfile.new(["tmp", ".pryrc"]).path

          mock_pry("edit -r #{path}", "$rand").should =~ /#{@rand}/

          File.unlink(path)
        end
      end
    end

    describe "with --ex" do
      before do
        @path = Tempfile.new(["tmp", ".rb"]).path
        File.open(@path, 'w'){ |f| f << "1\n2\nraise RuntimeError" }
      end
      after do
        File.unlink(@path)
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
          ":"
        }

        mock_pry("require #{@path.inspect}", "edit --ex", "FOO").should =~ /BAR/
      end

      it "should not reload the file if -n is passed" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "FOO2 = 'BAR'" }
          ":"
        }

        mock_pry("require #{@path.inspect}", "edit -n --ex", "FOO2").should.not =~ /BAR/
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

      it "should position the cursor at the end of the expression" do
        mock_pry("def a; 2;"," end", "edit")
        @line.should == 2
      end

      it "should delete the temporary file" do
        mock_pry("edit")
        File.exist?(@file).should == false
      end

      it "should evaluate the expression" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "'FOO'\n" }
          ":"
        }
        mock_pry("edit").should =~ /FOO/
      end
      it "should not evaluate the expression with -n" do
        Pry.config.editor = lambda {|file, line|
          File.open(file, 'w'){|f| f << "'FOO'\n" }
          ":"
        }
        mock_pry("edit -n").should.not =~ /FOO/
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
    
    it 'should output multiple methods\' sources' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method sample_method another_sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /def sample/
      str_output.string.should =~ /def another_sample/
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
