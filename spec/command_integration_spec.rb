require_relative 'helper'


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
    Pry.reset_defaults
  end

  describe "alias_command" do
    it 'should make an aliasd command behave like its original' do
      set = Pry::CommandSet.new do
        command "test-command" do
          output.puts "testing 1, 2, 3"
        end
        alias_command "test-alias", "test-command"
      end

      pry_tester(commands: set).tap do |t|
        expect(t.eval('test-command')).to eq t.eval('test-alias')
      end
    end

    it 'should pass on arguments to original' do
      set = Pry::CommandSet.new do
        command "test-command" do |*args|
          output.puts "testing #{args.join(' ')}"
        end
        alias_command "test-alias", "test-command"
      end

      t = pry_tester(commands: set)

      t.process_command "test-alias hello baby duck"
      expect(t.last_output).to match(/testing hello baby duck/)
    end

    it 'should pass option arguments to original' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        alias_command "test-alias", "ls"
      end

      obj = Class.new { @x = 10 }
      t = pry_tester(obj, commands: set)

      t.process_command "test-alias -i"
      expect(t.last_output).to match(/@x/)
    end

    it 'should pass option arguments to original with additional parameters' do
      set = Pry::CommandSet.new do
        import Pry::Commands
        alias_command "test-alias", "ls -M"
      end

      obj = Class.new { @x = Class.new { define_method(:plymouth) {} } }
      t = pry_tester(obj, commands: set)
      t.process_command "test-alias @x"
      expect(t.last_output).to match(/plymouth/)
    end

    it 'should be able to alias a regex command' do
      set = Pry::CommandSet.new do
        command(/du.k/) do
          output.puts "ducky"
        end
        alias_command "test-alias", "duck"
      end

      t = pry_tester(commands: set)
      t.process_command "test-alias"
      expect(t.last_output).to match(/ducky/)
    end

    it 'should be able to make the alias a regex' do
      set = Pry::CommandSet.new do
        command(/du.k/) do
          output.puts "ducky"
        end
        alias_command(/test-ali.s/, "duck")
      end

      redirect_pry_io(InputTester.new("test-alias"), out1 = StringIO.new) do
        Pry.start self, commands: set
      end

      expect(out1.string).to match(/ducky/)
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
        Pry.start(@o, commands: set)
      end

      expect(Pad.bs1.size).to eq 7
      expect(Pad.self).to eq @o
      expect(Pad.bs2.size).to eq 1
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
        Pry.start(@o, commands: set)
      end

      expect(Pad.bs1.size).to eq 7
      expect(Pad.self).to eq @o
      expect(Pad.bs2.size).to eq 1
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
        Pry.start(@o, commands: set)
      end

      expect(Pad.bs1.size).to eq 7
      expect(Pad.self).to eq @o
      expect(Pad.bs2.size).to eq 1
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

      expect(pry_tester(commands: klass).eval('run_v')).to match(/v command/)
    end

    it 'should run a regex command from within a command' do
      klass = Pry::CommandSet.new do
        command(/v(.*)?/) do |arg|
          output.puts "v #{arg}"
        end

        command "run_v" do
          run "vbaby"
        end
      end

      expect(pry_tester(commands: klass).eval('run_v')).to match(/v baby/)
    end

    it 'should run a command from within a command with arguments' do
      klass = Pry::CommandSet.new do
        command(/v(\w+)/) do |arg1, arg2|
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
        expect(pry_tester(commands: klass).eval(cmd)).to match(/v baby param/)
      end
    end
  end

  describe "Pry#run_command" do
    it 'should run a command that modifies the passed in eval_string' do
      p = Pry.new(output: @str_output)
      p.eval "def hello\npeter pan\n"
      p.run_command "amend-line !"
      expect(p.eval_string).to match(/def hello/)
      expect(p.eval_string).not_to match(/peter pan/)
    end

    it 'should run a command in the context of a session' do
      pry_tester(Object.new).tap do |t|
        t.eval "@session_ivar = 10", "_pry_.run_command('ls')"
        expect(t.last_output).to match(/@session_ivar/)
      end
    end
  end

  it 'should interpolate ruby code into commands' do
    set = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do |arg|
        arg
      end
    end

    expect(pry_tester(commands: set).eval('hello #{Pad.bong}')).to match(/bong/)
  end

  # bug fix for https://github.com/pry/pry/issues/170
  it 'should not choke on complex string interpolation when checking if ruby code is a command' do
    redirect_pry_io(InputTester.new('/#{Regexp.escape(File.expand_path("."))}/'), @str_output) do
      pry
    end

    expect(@str_output.string).not_to match(/SyntaxError/)
  end

  it 'should NOT interpolate ruby code into commands if :interpolate => false' do
    set = Pry::CommandSet.new do
      command "hello", "", keep_retval: true, interpolate: false do |arg|
        arg
      end
    end

    expect(pry_tester(commands: set).eval('hello #{Pad.bong}')).
      to match(/Pad\.bong/)
  end

  it 'should NOT try to interpolate pure ruby code (no commands) ' do
    # These should raise RuntimeError instead of NameError
    expect { pry_eval 'raise \'#{aggy}\'' }.to raise_error RuntimeError
    expect { pry_eval 'raise #{aggy}'     }.to raise_error RuntimeError

    expect(pry_eval('format \'#{my_var}\'')).to eq "\#{my_var}"
  end

  it 'should create a command with a space in its name zzz' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do
        output.puts "hello baby command"
      end
    end

    expect(pry_tester(commands: set).eval('hello baby')).
      to match(/hello baby command/)
  end

  it 'should create a command with a space in its name and pass an argument' do
    set = Pry::CommandSet.new do
      command "hello baby", "" do |arg|
        output.puts "hello baby command #{arg}"
      end
    end

    expect(pry_tester(commands: set).eval('hello baby john')).
      to match(/hello baby command john/)
  end

  it 'should create a regex command and be able to invoke it' do
    set = Pry::CommandSet.new do
      command(/hello(.)/, "") do
        c = captures.first
        output.puts "hello#{c}"
      end
    end

    expect(pry_tester(commands: set).eval('hello1')).to match(/hello1/)
  end

  it 'should create a regex command and pass captures into the args list before regular arguments' do
    set = Pry::CommandSet.new do
      command(/hello(.)/, "") do |c1, a1|
        output.puts "hello #{c1} #{a1}"
      end
    end

    expect(pry_tester(commands: set).eval('hello1 baby')).to match(/hello 1 baby/)
  end

  it 'should create a regex command and interpolate the captures' do
    set = Pry::CommandSet.new do
      command(/hello (.*)/, "") do |c1|
        output.puts "hello #{c1}"
      end
    end

    bong = "bong"
    expect(pry_tester(binding, commands: set).eval('hello #{bong}')).
      to match(/hello #{bong}/)
  end

  it 'should create a regex command and arg_string should be interpolated' do
    set = Pry::CommandSet.new do
      command(/hello(\w+)/, "") do |c1, a1, a2, a3|
        output.puts "hello #{c1} #{a1} #{a2} #{a3}"
      end
    end

    bing = 'bing'
    bong = 'bong'
    bang = 'bang'

    expect(pry_tester(binding, commands: set).
      eval('hellojohn #{bing} #{bong} #{bang}')).
      to match(/hello john #{bing} #{bong} #{bang}/)
  end

  it 'if a regex capture is missing it should be nil' do
    set = Pry::CommandSet.new do
      command(/hello(.)?/, "") do |c1, a1|
        output.puts "hello #{c1.inspect} #{a1}"
      end
    end

    expect(pry_tester(commands: set).eval('hello baby')).to match(/hello nil baby/)
  end

  it 'should create a command in a nested context and that command should be accessible from the parent' do
    expect(pry_tester(Object.new).eval(*(<<-RUBY.split("\n")))).to match(/instance variables:\s+@x/m)
      @x = nil
      cd 7
      _pry_.commands.instance_eval { command('bing') { |arg| run arg } }
      cd ..
      bing ls
    RUBY
  end

  it 'should define a command that keeps its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do
        :kept_hello
      end
    end

    t = pry_tester(commands: klass)
    t.eval("hello\n")
    expect(t.last_command_result).to eq :kept_hello
  end

  it 'should define a command that does NOT keep its return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: false do
        :kept_hello
      end
    end

    t = pry_tester(commands: klass)
    expect(t.eval("hello\n")).to eq ''
    expect(t.last_command_result).to eq Pry::Command::VOID_VALUE
  end

  it 'should define a command that keeps its return value even when nil' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do
        nil
      end
    end

    t = pry_tester(commands: klass)
    t.eval("hello\n")
    expect(t.last_command_result).to eq nil
  end

  it 'should define a command that keeps its return value but does not return when value is void' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do
        void
      end
    end

    expect(pry_tester(commands: klass).eval("hello\n").empty?).to eq true
  end

  it 'a command (with :keep_retval => false) that replaces eval_string with a valid expression should not have the expression value suppressed' do
    klass = Pry::CommandSet.new do
      command "hello", "" do
        eval_string.replace("6")
      end
    end

    redirect_pry_io(InputTester.new('def yo', 'hello'), @str_output) do
      Pry.start self, commands: klass
    end

    expect(@str_output.string).to match(/6/)
  end

  it 'a command (with :keep_retval => true) that replaces eval_string with a valid expression should overwrite the eval_string with the return value' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do
        eval_string.replace("6")
        7
      end
    end

    expect(pry_tester(commands: klass).eval("def yo\nhello\n")).to eq 7
  end

  it 'a command that return a value in a multi-line expression should clear the expression and return the value' do
    klass = Pry::CommandSet.new do
      command "hello", "", keep_retval: true do
        5
      end
    end

    expect(pry_tester(commands: klass).eval("def yo\nhello\n")).to eq 5
  end

  it 'should set the commands default, and the default should be overridable' do
    klass = Pry::CommandSet.new do
      command "hello" do
        output.puts "hello world"
      end
    end

    other_klass = Pry::CommandSet.new do
      command "goodbye", "" do
        output.puts "goodbye world"
      end
    end

    Pry.config.commands = klass
    expect(pry_tester.eval("hello")).to eq "hello world\n"
    expect(pry_tester(commands: other_klass).eval("goodbye")).to eq "goodbye world\n"
  end

  it 'should inherit commands from Pry::Commands' do
    klass = Pry::CommandSet.new Pry::Commands do
      command "v" do
      end
    end

    expect(klass.to_hash.include?("nesting")).to eq true
    expect(klass.to_hash.include?("jump-to")).to eq true
    expect(klass.to_hash.include?("cd")).to eq true
    expect(klass.to_hash.include?("v")).to eq true
  end

  it 'should change description of a command using desc' do
    klass = Pry::CommandSet.new do
      import Pry::Commands
    end
    orig = klass["help"].description
    klass.instance_eval do
      desc "help", "blah"
    end
    commands = klass.to_hash
    expect(commands["help"].description).not_to eq orig
    expect(commands["help"].description).to eq "blah"
  end

  it 'should enable an inherited method to access opts and output and target, due to instance_exec' do
    klass = Pry::CommandSet.new do
      command "v" do
        output.puts "#{target.eval('self')}"
      end
    end

    child_klass = Pry::CommandSet.new klass do
    end

    mock_pry(Pry.binding_for('john'), "v", print: proc {}, commands: child_klass,
                                           output: @str_output)

    expect(@str_output.string).to eq "john\n"
  end

  it 'should import commands from another command object' do
    klass = Pry::CommandSet.new do
      import_from Pry::Commands, "ls", "jump-to"
    end

    expect(klass.to_hash.include?("ls")).to eq true
    expect(klass.to_hash.include?("jump-to")).to eq true
  end

  it 'should delete some inherited commands when using delete method' do
    klass = Pry::CommandSet.new Pry::Commands do
      command "v" do
      end

      delete "show-doc", "show-method"
      delete "ls"
    end

    commands = klass.to_hash
    expect(commands.include?("nesting")).to eq true
    expect(commands.include?("jump-to")).to eq true
    expect(commands.include?("cd")).to eq true
    expect(commands.include?("v")).to eq true
    expect(commands.include?("show-doc")).to eq false
    expect(commands.include?("show-method")).to eq false
    expect(commands.include?("ls")).to eq false
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

    t = pry_tester(commands: klass)
    expect(t.eval('jump-to')).to eq "jump-to the music\n"
    expect(t.eval('help')).to eq "help to the music\n"
  end

  it 'should run a command with no parameter' do
    expect(pry_tester(commands: @command_tester).eval('command1')).
      to eq "command1\n"
  end

  it 'should run a command with one parameter' do
    expect(pry_tester(commands: @command_tester).eval('command2 horsey')).
      to eq "horsey\n"
  end
end
