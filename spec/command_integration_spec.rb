require 'helper'


describe "commands" do
  before do
    @str_output = StringIO.new
    @o = Object.new

    # Shortcuts. They save a lot of typing.
    @bs1 = "Pad.bs1 = _pry_.binding_stack.dup"
    @bs2 = "Pad.bs2 = _pry_.binding_stack.dup"
    @bs3 = "Pad.bs3 = _pry_.binding_stack.dup"

    @self  = "Pad.self = self"

    @command_tester = Pry::CommandSet.new do
      command "command1", "command 1 test" do
        output.puts "command1"
      end

      command "command2", "command 2 test" do |arg|
        output.puts arg
      end
    end

    Pad.bong = "bong"
  end

  after do
    Pad.clear
  end

  describe "alias_command" do
    it 'should make an aliasd command behave like its original' do
      set = Pry::CommandSet.new do
        command "test-command" do
          output.puts "testing 1, 2, 3"
        end
        alias_command "test-alias", "test-command"
      end
      redirect_pry_io(InputTester.new("test-alias"), out1 = StringIO.new) do
        Pry.start self, :commands => set
      end

      redirect_pry_io(InputTester.new("test-command"), out2 = StringIO.new) do
        Pry.start self, :commands => set
      end

      out1.string.should == out2.string
    end

    it 'should pass on arguments to original' do
      set = Pry::CommandSet.new do
        command "test-command" do |*args|
          output.puts "testing #{args.join(' ')}"
        end
        alias_command "test-alias", "test-command"
      end

      t = pry_tester(:commands => set)

      t.process_command "test-alias hello baby duck"
      t.last_output.should =~ /testing hello baby duck/
    end

    it 'should pass option arguments to original' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        alias_command "test-alias", "ls"
      end

      obj = Class.new { @x = 10 }
      t = pry_tester(obj, :commands => set)

      t.process_command "test-alias -i"
      t.last_output.should =~ /@x/
    end

    it 'should pass option arguments to original with additional parameters' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        alias_command "test-alias", "ls -M"
      end

      obj = Class.new { @x = Class.new { define_method(:plymouth) {} } }
      t = pry_tester(obj, :commands => set)
      t.process_command "test-alias @x"
      t.last_output.should =~ /plymouth/
    end

    it 'should be able to alias a regex command' do
      set = Pry::CommandSet.new do
        command /du.k/ do
          output.puts "ducky"
        end
        alias_command "test-alias", "duck"
      end

      t = pry_tester(:commands => set)
      t.process_command "test-alias"
      t.last_output.should =~ /ducky/
    end

    it 'should be able to make the alias a regex' do
      set = Pry::CommandSet.new do
        command /du.k/ do
          output.puts "ducky"
        end
        alias_command /test-ali.s/, "duck"
      end

      redirect_pry_io(InputTester.new("test-alias"), out1 = StringIO.new) do
        Pry.start self, :commands => set
      end

      out1.string.should =~ /ducky/
    end
  end

  describe "Pry::Command#run" do
    it 'should allow running of commands with following whitespace' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        command "test-run" do
          run "cd / "
        end
      end

      redirect_pry_io(InputTester.new("cd 1/2/3/4/5/6", @bs1, "test-run",
                                      @self, @bs2, "exit-all")) do
        Pry.start(@o, :commands => set)
      end

      Pad.bs1.size.should == 7
      Pad.self.should == @o
      Pad.bs2.size.should == 1
    end

    it 'should allow running of cd command when contained in a single string' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        command "test-run" do
          run "cd /"
        end
      end
      redirect_pry_io(InputTester.new("cd 1/2/3/4/5/6", @bs1, "test-run",
                                      @self, @bs2, "exit-all")) do
        Pry.start(@o, :commands => set)
      end

      Pad.bs1.size.should == 7
      Pad.self.should == @o
      Pad.bs2.size.should == 1
    end

    it 'should allow running of cd command when split into array' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        command "test-run" do
          run "cd", "/"
        end
      end
      redirect_pry_io(InputTester.new("cd 1/2/3/4/5/6", @bs1, "test-run",
                                      @self, @bs2, "exit-all")) do
        Pry.start(@o, :commands => set)
      end

      Pad.bs1.size.should == 7
      Pad.self.should == @o
      Pad.bs2.size.should == 1
    end

    it 'should run a command from within a command' do
      klass = Pry::CommandSet.new do
        command "v" do
          output.puts "v command"
        end

        command "run_v" do
          run "v"
        end
      end

      Pry.new(:input => InputTester.new("run_v"), :output => @str_output, :commands => klass).rep

      @str_output.string.should =~ /v command/
    end

    it 'should run a regex command from within a command' do
      klass = Pry::CommandSet.new do
        command /v(.*)?/ do |arg|
          output.puts "v #{arg}"
        end

        command "run_v" do
          run "vbaby"
        end
      end

      redirect_pry_io(InputTester.new("run_v"), @str_output) do
        Pry.new(:commands => klass).rep
      end

      @str_output.string.should =~ /v baby/
    end

    it 'should run a command from within a command with arguments' do
      klass = Pry::CommandSet.new do
        command /v(\w+)/ do |arg1, arg2|
          output.puts "v #{arg1} #{arg2}"
        end

        command "run_v_explicit_parameter" do
          run "vbaby", "param"
        end

        command "run_v_embedded_parameter" do
          run "vbaby param"
        end
      end

      ["run_v_explicit_parameter", "run_v_embedded_parameter"].each do |cmd|
        redirect_pry_io(InputTester.new(cmd), @str_output) do
          Pry.new(:commands => klass).rep
        end
        @str_output.string.should =~ /v baby param/
      end
    end
  end

  describe "Pry#run_command" do
    it 'should run a command in a specified context' do
      b = Pry.binding_for('seven')
      p = Pry.new(:output => @str_output)
      p.run_command("ls -m", "", b)
      p.output.string.should =~ /downcase/
    end

    it 'should run a command that modifies the passed in eval_string' do
      b = Pry.binding_for(7)
      p = Pry.new(:output => @str_output)
      eval_string = "def hello\npeter pan\n"
      p.run_command("amend-line !", eval_string, b)
      eval_string.should =~ /def hello/
      eval_string.should.not =~ /peter pan/
    end

    it 'should run a command in the context of a session' do
      pry_tester.tap do |t|
        t.eval "@session_ivar = 10", "_pry_.run_command('ls')"
        t.last_output.should =~ /@session_ivar/
      end
    end
  end

  it 'should interpolate ruby code into commands' do
    set = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do |arg|
        arg
      end
    end

    str_input = StringIO.new('hello #{Pad.bong}')
    Pry.new(:input => str_input, :output => @str_output, :commands => set).rep

    @str_output.string.should =~ /bong/
  end

  # bug fix for https://github.com/pry/pry/issues/170
  it 'should not choke on complex string interpolation when checking if ruby code is a command' do
    redirect_pry_io(InputTester.new('/#{Regexp.escape(File.expand_path("."))}/'), @str_output) do
      pry
    end

    @str_output.string.should.not =~ /SyntaxError/
  end

  it 'should NOT interpolate ruby code into commands if :interpolate => false' do
    set = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true, :interpolate => false do |arg|
        arg
      end
    end

    str_input = StringIO.new('hello #{Pad.bong}')
    Pry.new(:input => str_input, :output => @str_output, :commands => set).rep

    @str_output.string.should =~ /Pad\.bong/
  end

  it 'should NOT try to interpolate pure ruby code (no commands) ' do
    Pry.new(:input => StringIO.new('format \'#{aggy}\''), :output => @str_output).rep
    @str_output.string.should.not =~ /NameError/

    @str_output = StringIO.new
    Pry.new(:input => StringIO.new('format #{aggy}'), :output => @str_output).rep
    @str_output.string.should.not =~ /NameError/

    @str_output = StringIO.new
    Pad.interp = "bong"
    Pry.new(:input => StringIO.new('format \'#{Pad.interp}\''), :output => @str_output).rep

    @str_output.string.should.not =~ /bong/
  end

  it 'should create a command with a space in its name' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do
        output.puts "hello baby command"
      end
    end

    redirect_pry_io(InputTester.new("hello baby", "exit-all"), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello baby command/
  end

  it 'should create a command with a space in its name and pass an argument' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do |arg|
        output.puts "hello baby command #{arg}"
      end
    end

    redirect_pry_io(InputTester.new("hello baby john"), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello baby command john/
  end

  it 'should create a regex command and be able to invoke it' do
    set = Pry::CommandSet.new do
      command /hello(.)/, "" do
        c = captures.first
        output.puts "hello#{c}"
      end
    end

    redirect_pry_io(InputTester.new("hello1"), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello1/
  end

  it 'should create a regex command and pass captures into the args list before regular arguments' do
    set = Pry::CommandSet.new do
      command /hello(.)/, "" do |c1, a1|
        output.puts "hello #{c1} #{a1}"
      end
    end

    redirect_pry_io(InputTester.new("hello1 baby"), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello 1 baby/
  end

  it 'should create a regex command and interpolate the captures' do
    set = Pry::CommandSet.new do
      command /hello (.*)/, "" do |c1|
        output.puts "hello #{c1}"
      end
    end

    redirect_pry_io(InputTester.new('hello #{Pad.bong}'), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello bong/
  end

  it 'should create a regex command and arg_string should be interpolated' do
    set = Pry::CommandSet.new do
      command /hello(\w+)/, "" do |c1, a1, a2, a3|
        output.puts "hello #{c1} #{a1} #{a2} #{a3}"
      end
    end

    Pad.bing = "bing"
    Pad.bang = "bang"
    redirect_pry_io(InputTester.new('hellojohn #{Pad.bing} #{Pad.bong} #{Pad.bang}'),
                    @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello john bing bong bang/
  end

  it 'if a regex capture is missing it should be nil' do
    set = Pry::CommandSet.new do
      command /hello(.)?/, "" do |c1, a1|
        output.puts "hello #{c1.inspect} #{a1}"
      end
    end

    redirect_pry_io(InputTester.new("hello baby"), @str_output) do
      Pry.new(:commands => set).rep
    end

    @str_output.string.should =~ /hello nil baby/
  end

  it 'should create a command in a nested context and that command should be accessible from the parent' do
    x = "@x=nil\ncd 7\n_pry_.commands.instance_eval {\ncommand('bing') { |arg| run arg }\n}\ncd ..\nbing ls\nexit-all"
    redirect_pry_io(StringIO.new("@x=nil\ncd 7\n_pry_.commands.instance_eval {\ncommand('bing') { |arg| run arg }\n}\ncd ..\nbing ls\nexit-all"), @str_output) do
      Pry.new.repl('0')
    end

    @str_output.string.should =~ /@x/
  end

  it 'should define a command that keeps its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        :kept_hello
      end
    end

    Pry.new(:input => StringIO.new("hello\n"), :output => @str_output, :commands => klass).rep
    @str_output.string.should =~ /:kept_hello/
    @str_output.string.should =~ /=>/
  end

  it 'should define a command that does NOT keep its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => false do
        :kept_hello
      end
    end

    Pry.new(:input => StringIO.new("hello\n"), :output => @str_output, :commands => klass).rep
    (@str_output.string =~ /:kept_hello/).should == nil
    @str_output.string !~ /=>/
  end

  it 'should define a command that keeps its return value even when nil' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        nil
      end
    end

    Pry.new(:input => StringIO.new("hello\n"), :output => @str_output, :commands => klass).rep

    @str_output.string.should =~ /nil/
    @str_output.string.should =~ /=>/
  end

  it 'should define a command that keeps its return value but does not return when value is void' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        void
      end
    end

    Pry.new(:input => StringIO.new("hello\n"), :output => @str_output, :commands => klass).rep
    @str_output.string.empty?.should == true
  end

  it 'a command (with :keep_retval => false) that replaces eval_string with a valid expression should not have the expression value suppressed' do
    klass = Pry::CommandSet.new do
      command "hello", "" do
        eval_string.replace("6")
      end
    end

    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => @str_output, :commands => klass).rep
    @str_output.string.should =~ /6/
  end

  it 'a command (with :keep_retval => true) that replaces eval_string with a valid expression should overwrite the eval_string with the return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        eval_string.replace("6")
        7
      end
    end

    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => @str_output, :commands => klass).rep

    @str_output.string.should =~ /7/
    @str_output.string.should.not =~ /6/
  end

  it 'a command that return a value in a multi-line expression should clear the expression and return the value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        5
      end
    end

    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => @str_output, :commands => klass).rep

    @str_output.string.should =~ /5/
  end

  it 'should set the commands default, and the default should be overridable' do
    klass = Pry::CommandSet.new do
      command "hello" do
        output.puts "hello world"
      end
    end

    Pry.commands = klass

    Pry.new(:input => InputTester.new("hello"), :output => @str_output).rep
    @str_output.string.should =~ /hello world/

    other_klass = Pry::CommandSet.new do
      command "goodbye", "" do
        output.puts "goodbye world"
      end
    end

    @str_output = StringIO.new

    Pry.new(:input => InputTester.new("goodbye"), :output => @str_output, :commands => other_klass).rep
    @str_output.string.should =~ /goodbye world/
  end

  it 'should inherit commands from Pry::Commands' do
    klass = Pry::CommandSet.new Pry::Commands do
      command "v" do
      end
    end

    klass.commands.include?("nesting").should == true
    klass.commands.include?("jump-to").should == true
    klass.commands.include?("cd").should == true
    klass.commands.include?("v").should == true
  end

  it 'should change description of a command using desc' do
    klass = Pry::CommandSet.new do
      import Pry::Commands
    end
    orig = klass.commands["help"].description
    klass.instance_eval do
      desc "help", "blah"
    end
    klass.commands["help"].description.should.not == orig
    klass.commands["help"].description.should == "blah"
  end

  it 'should enable an inherited method to access opts and output and target, due to instance_exec' do
    klass = Pry::CommandSet.new do
      command "v" do
        output.puts "#{target.eval('self')}"
      end
    end

    child_klass = Pry::CommandSet.new klass do
    end

    Pry.new(:print => proc {}, :input => InputTester.new("v"),
            :output => @str_output, :commands => child_klass).rep("john")

    @str_output.string.rstrip.should == "john"
  end

  it 'should import commands from another command object' do
    klass = Pry::CommandSet.new do
      import_from Pry::Commands, "ls", "jump-to"
    end

    klass.commands.include?("ls").should == true
    klass.commands.include?("jump-to").should == true
  end

  it 'should delete some inherited commands when using delete method' do
    klass = Pry::CommandSet.new Pry::Commands do
      command "v" do
      end

      delete "show-doc", "show-method"
      delete "ls"
    end

    klass.commands.include?("nesting").should == true
    klass.commands.include?("jump-to").should == true
    klass.commands.include?("cd").should == true
    klass.commands.include?("v").should == true
    klass.commands.include?("show-doc").should == false
    klass.commands.include?("show-method").should == false
    klass.commands.include?("ls").should == false
  end

  it 'should override some inherited commands' do
    klass = Pry::CommandSet.new Pry::Commands do
      command "jump-to" do
        output.puts "jump-to the music"
      end

      command "help" do
        output.puts "help to the music"
      end
    end

    # suppress evaluation output
    Pry.print = proc {}

    Pry.new(:input => InputTester.new("jump-to"), :output => @str_output, :commands => klass).rep
    @str_output.string.rstrip.should == "jump-to the music"

    @str_output = StringIO.new
    Pry.new(:input => InputTester.new("help"), :output => @str_output, :commands => klass).rep
    @str_output.string.should == "help to the music\n"


    Pry.reset_defaults
    Pry.color = false
  end

  it 'should run a command with no parameter' do
    pry_tester = Pry.new
    pry_tester.commands = @command_tester
    pry_tester.input = InputTester.new("command1", "exit-all")
    pry_tester.commands = @command_tester

    pry_tester.output = @str_output

    pry_tester.rep

    @str_output.string.should =~ /command1/
  end

  it 'should run a command with one parameter' do
    pry_tester = Pry.new
    pry_tester.commands = @command_tester
    pry_tester.input = InputTester.new("command2 horsey", "exit-all")
    pry_tester.commands = @command_tester

    pry_tester.output = @str_output

    pry_tester.rep

    @str_output.string.should =~ /horsey/
  end
end
