require 'helper'
describe "commands" do
  it 'should interpolate ruby code into commands' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do |arg|
        arg
      end
    end

    $test_interpolation = "bing"
    str_output = StringIO.new
    Pry.new(:input => StringIO.new('hello #{$test_interpolation}'), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /bing/
    $test_interpolation = nil
  end

  # bug fix for https://github.com/pry/pry/issues/170
  it 'should not choke on complex string interpolation when checking if ruby code is a command' do
    redirect_pry_io(InputTester.new('/#{Regexp.escape(File.expand_path("."))}/'), str_output = StringIO.new) do
      pry
    end

    str_output.string.should.not =~ /SyntaxError/
  end

  it 'should NOT interpolate ruby code into commands if :interpolate => false' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true, :interpolate => false do |arg|
        arg
      end
    end

    $test_interpolation = "bing"
    str_output = StringIO.new
    Pry.new(:input => StringIO.new('hello #{$test_interpolation}'), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /test_interpolation/
    $test_interpolation = nil
  end

  it 'should NOT try to interpolate pure ruby code (no commands) ' do
    str_output = StringIO.new
    Pry.new(:input => StringIO.new('format \'#{aggy}\''), :output => str_output).rep
    str_output.string.should.not =~ /NameError/

    Pry.new(:input => StringIO.new('format #{aggy}'), :output => str_output).rep
    str_output.string.should.not =~ /NameError/

    $test_interpolation = "blah"
    Pry.new(:input => StringIO.new('format \'#{$test_interpolation}\''), :output => str_output).rep

    str_output.string.should.not =~ /blah/
    $test_interpolation = nil
  end

  it 'should create a command with a space in its name' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do
        output.puts "hello baby command"
      end
    end

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("hello baby", "exit-all"), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello baby command/
  end

  it 'should create a command with a space in its name and pass an argument' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do |arg|
        output.puts "hello baby command #{arg}"
      end
    end

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("hello baby john"), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello baby command john/
  end

  it 'should create a regex command and be able to invoke it' do
    set = Pry::CommandSet.new do
      command /hello(.)/, "" do
        c = captures.first
        output.puts "hello#{c}"
      end
    end

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("hello1"), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello1/
  end

  it 'should create a regex command and pass captures into the args list before regular arguments' do
    set = Pry::CommandSet.new do
      command /hello(.)/, "" do |c1, a1|
        output.puts "hello #{c1} #{a1}"
      end
    end

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("hello1 baby"), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello 1 baby/
  end

  it 'should create a regex command and interpolate the captures' do
    set = Pry::CommandSet.new do
      command /hello (.*)/, "" do |c1|
        output.puts "hello #{c1}"
      end
    end

    str_output = StringIO.new
    $obj = "bing"
    redirect_pry_io(InputTester.new('hello #{$obj}'), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello bing/
    $obj = nil
  end

  it 'should create a regex command and arg_string should be interpolated' do
    set = Pry::CommandSet.new do
      command /hello(\w+)/, "" do |c1, a1, a2, a3|
        output.puts "hello #{c1} #{a1} #{a2} #{a3}"
      end
    end

    str_output = StringIO.new
    $a1 = "bing"
    $a2 = "bong"
    $a3 = "bang"
    redirect_pry_io(InputTester.new('hellojohn #{$a1} #{$a2} #{$a3}'), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello john bing bong bang/

    $a1 = nil
    $a2 = nil
    $a3 = nil
  end


  it 'if a regex capture is missing it should be nil' do
    set = Pry::CommandSet.new do
      command /hello(.)?/, "" do |c1, a1|
        output.puts "hello #{c1.inspect} #{a1}"
      end
    end

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("hello baby"), str_output) do
      Pry.new(:commands => set).rep
    end

    str_output.string.should =~ /hello nil baby/
  end

  it 'should create a command in  a nested context and that command should be accessible from the parent' do
    str_output = StringIO.new
    x = "@x=nil\ncd 7\n_pry_.commands.instance_eval {\ncommand('bing') { |arg| run arg }\n}\ncd ..\nbing ls\nexit-all"
    redirect_pry_io(StringIO.new("@x=nil\ncd 7\n_pry_.commands.instance_eval {\ncommand('bing') { |arg| run arg }\n}\ncd ..\nbing ls\nexit-all"), str_output) do
      Pry.new.repl(0)
    end

    str_output.string.should =~ /@x/
  end

  it 'should define a command that keeps its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        :kept_hello
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /:kept_hello/
    str_output.string.should =~ /=>/
  end

  it 'should define a command that does NOT keep its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => false do
        :kept_hello
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => klass).rep
    (str_output.string =~ /:kept_hello/).should == nil
      str_output.string !~ /=>/
  end

  it 'should define a command that keeps its return value even when nil' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        nil
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /nil/
        str_output.string.should =~ /=>/
  end

  it 'should define a command that keeps its return value but does not return when value is void' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        void
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => klass).rep
    str_output.string.empty?.should == true
  end

  it 'a command (with :keep_retval => false) that replaces eval_string with a valid expression should not have the expression value suppressed' do
    klass = Pry::CommandSet.new do
      command "hello", "" do
        eval_string.replace("6")
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /6/
  end


  it 'a command (with :keep_retval => true) that replaces eval_string with a valid expression should overwrite the eval_string with the return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        eval_string.replace("6")
        7
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /7/
    str_output.string.should.not =~ /6/
  end

  it 'a command that return a value in a multi-line expression should clear the expression and return the value' do
    klass = Pry::CommandSet.new do
      command "hello", "", :keep_retval => true do
        5
      end
    end
    str_output = StringIO.new
    Pry.new(:input => StringIO.new("def yo\nhello\n"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /5/
  end


  it 'should set the commands default, and the default should be overridable' do
    klass = Pry::CommandSet.new do
      command "hello" do
        output.puts "hello world"
      end
    end

    Pry.commands = klass

    str_output = StringIO.new
    Pry.new(:input => InputTester.new("hello"), :output => str_output).rep
    str_output.string.should =~ /hello world/

    other_klass = Pry::CommandSet.new do
      command "goodbye", "" do
        output.puts "goodbye world"
      end
    end

    str_output = StringIO.new

    Pry.new(:input => InputTester.new("goodbye"), :output => str_output, :commands => other_klass).rep
    str_output.string.should =~ /goodbye world/
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

  it 'should alias a command with another command' do
    klass = Pry::CommandSet.new do
      import Pry::DefaultCommands::Help
      alias_command "help2", "help"
    end
    klass.commands["help2"].block.should == klass.commands["help"].block
  end

  it 'should change description of a command using desc' do
    klass = Pry::CommandSet.new do; import Pry::DefaultCommands::Help; end
    orig = klass.commands["help"].description
    klass.instance_eval do
      desc "help", "blah"
    end
    klass.commands["help"].description.should.not == orig
    klass.commands["help"].description.should == "blah"
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

    str_output = StringIO.new
    Pry.new(:input => InputTester.new("run_v"), :output => str_output, :commands => klass).rep
    str_output.string.should =~ /v command/
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

    str_output = StringIO.new
    redirect_pry_io(InputTester.new("run_v"), str_output) do
      Pry.new(:commands => klass).rep
    end

    str_output.string.should =~ /v baby/
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
      str_output = StringIO.new
      redirect_pry_io(InputTester.new(cmd), str_output) do
        Pry.new(:commands => klass).rep
      end
      str_output.string.should =~ /v baby param/
    end
  end

  it 'should enable an inherited method to access opts and output and target, due to instance_exec' do
    klass = Pry::CommandSet.new do
      command "v" do
        output.puts "#{target.eval('self')}"
      end
    end

    child_klass = Pry::CommandSet.new klass do
    end

    str_output = StringIO.new
    Pry.new(:print => proc {}, :input => InputTester.new("v"),
            :output => str_output, :commands => child_klass).rep("john")

    str_output.string.rstrip.should == "john"
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

    str_output = StringIO.new
    Pry.new(:input => InputTester.new("jump-to"), :output => str_output, :commands => klass).rep
    str_output.string.rstrip.should == "jump-to the music"

    str_output = StringIO.new
    Pry.new(:input => InputTester.new("help"), :output => str_output, :commands => klass).rep
    str_output.string.should == "help to the music\n"


    Pry.reset_defaults
    Pry.color = false
  end

  it 'should run a command with no parameter' do
    pry_tester = Pry.new
    pry_tester.commands = CommandTester
    pry_tester.input = InputTester.new("command1", "exit-all")
    pry_tester.commands = CommandTester

    str_output = StringIO.new
    pry_tester.output = str_output

    pry_tester.rep

    str_output.string.should =~ /command1/
  end

  it 'should run a command with one parameter' do
    pry_tester = Pry.new
    pry_tester.commands = CommandTester
    pry_tester.input = InputTester.new("command2 horsey", "exit-all")
    pry_tester.commands = CommandTester

    str_output = StringIO.new
    pry_tester.output = str_output

    pry_tester.rep

    str_output.string.should =~ /horsey/
  end
end

describe "Pry#run_command" do
  it 'should run a command in a specified context' do
    b = Pry.binding_for(7)
    p = Pry.new(:output => StringIO.new)
    p.run_command("ls -m", "", b)
    p.output.string.should =~ /divmod/
  end

  it 'should run a command that modifies the passed in eval_string' do
    b = Pry.binding_for(7)
    p = Pry.new(:output => StringIO.new)
    eval_string = "def hello\npeter pan\n"
    p.run_command("amend-line !", eval_string, b)
    eval_string.should =~ /def hello/
    eval_string.should.not =~ /peter pan/
  end

  it 'should run a command in the context of a session' do
    mock_pry("@session_ivar = 10", "_pry_.run_command('ls')").should =~ /@session_ivar/
  end
end


