require 'helper'

describe Pry do

  # if RUBY_PLATFORM !~ /mingw/ && RUBY_PLATFORM !~ /mswin/ && RUBY_PLATFORM != 'java'
  #   describe 'warning emissions' do
  #     it 'should emit no warnings' do
  #       Open4.popen4 'ruby -I lib -rubygems -r"pry" -W -e "exit"' do |pid, stdin, stdout, stderr|
  #         stderr.read.empty?.should == true
  #       end
  #     end
  #   end
  # end

  if RUBY_VERSION =~ /1.9/
    describe "Exotic object support" do
      # regression test for exotic object support
      it "Should not error when return value is a BasicObject instance" do

        lambda do
          redirect_pry_io(InputTester.new("BasicObject.new", "exit-all"), StringIO.new) do
            Pry.start
          end
        end.should.not.raise NoMethodError

      end
    end
  end

  describe "Pry.binding_for" do

    # regression test for burg's bug (see git history)
    it "Should not error when object doesn't have a valid == method" do
      o = Object.new
      def o.==(other)
        raise
      end

      lambda { Pry.binding_for(o) }.should.not.raise Exception
    end
  end

  describe "open a Pry session on an object" do
    describe "rep" do
      before do
        class Hello
        end
      end

      after do
        Object.send(:remove_const, :Hello)
      end

      # bug fix for https://github.com/banister/pry/issues/93
      it 'should not leak pry constants into Object namespace' do
        input_string = "CommandContext"
        str_output = StringIO.new
        o = Object.new
        pry_tester = Pry.new(:input => StringIO.new(input_string),
                             :output => str_output,
                             :exception_handler => proc { |_, exception, _pry_| @excep = exception },
                             :print => proc {}
                             ).rep(o)

        @excep.is_a?(NameError).should == true
      end

      if defined?(BasicObject)
        it 'should be able to operate inside the BasicObject class' do
          $obj = nil
          redirect_pry_io(InputTester.new(":foo", "$obj = _", "exit-all"), StringIO.new) do
            BasicObject.pry
          end
          $obj.should == :foo
          $obj = nil
        end
      end

      it 'should set an ivar on an object' do
        input_string = "@x = 10"
        input = InputTester.new(input_string)
        o = Object.new

        pry_tester = Pry.new(:input => input, :output => Pry::NullOutput)
        pry_tester.rep(o)
        o.instance_variable_get(:@x).should == 10
      end

      it 'should display error and throw(:breakout) if Pry instance runs out of input' do
        str_output = StringIO.new
        catch(:breakout) do
          redirect_pry_io(StringIO.new(":nothing\n"), str_output) do
            Pry.new.repl
          end
        end
        str_output.string.should =~ /Error: Pry ran out of things to read/
      end

      it 'should make self evaluate to the receiver of the rep session' do
        o = :john
        str_output = StringIO.new

        pry_tester = Pry.new(:input => InputTester.new("self"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should =~ /:john/
      end

      it 'should work with multi-line input' do
        o = Object.new
        str_output = StringIO.new

        pry_tester = Pry.new(:input => InputTester.new("x = ", "1 + 4"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should =~ /5/
      end

      it 'should define a nested class under Hello and not on top-level or Pry' do
        pry_tester = Pry.new(:input => InputTester.new("class Nested", "end"), :output => Pry::NullOutput)
        pry_tester.rep(Hello)
        Hello.const_defined?(:Nested).should == true
      end

      it 'should suppress output if input ends in a ";" and is an Exception object (single line)' do
        o = Object.new
        str_output = StringIO.new

        pry_tester = Pry.new(:input => InputTester.new("Exception.new;"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should == ""
      end

      it 'should suppress output if input ends in a ";" (single line)' do
        o = Object.new
        str_output = StringIO.new

        pry_tester = Pry.new(:input => InputTester.new("x = 5;"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should == ""
      end

      it 'should suppress output if input ends in a ";" (multi-line)' do
        o = Object.new
        str_output = StringIO.new

        pry_tester = Pry.new(:input => InputTester.new("def self.blah", ":test", "end;"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should == ""
      end

      it 'should be able to evaluate exceptions normally' do
        o = Exception.new
        str_output = StringIO.new

        was_called = false
        pry_tester = Pry.new(:input => InputTester.new("self"),
                             :output => str_output,
                             :exception_handler => proc { was_called = true })

        pry_tester.rep(o)
        was_called.should == false
      end

      it 'should notice when exceptions are raised' do
        o = Exception.new
        str_output = StringIO.new

        was_called = false
        pry_tester = Pry.new(:input => InputTester.new("raise self"),
                             :output => str_output,
                             :exception_handler => proc { was_called = true })

        pry_tester.rep(o)
        was_called.should == true
      end

      it 'should not try to catch intended exceptions' do
        lambda { mock_pry("raise SystemExit") }.should.raise SystemExit
        # SIGTERM
        lambda { mock_pry("raise SignalException.new(15)") }.should.raise SignalException
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

    describe "repl" do
      describe "basic functionality" do
        it 'should set an ivar on an object and exit the repl' do
          input_strings = ["@x = 10", "exit-all"]
          input = InputTester.new(*input_strings)

          o = Object.new

          pry_tester = Pry.start(o, :input => input, :output => Pry::NullOutput)

          o.instance_variable_get(:@x).should == 10
        end
      end

      describe "valid_expression?" do
        it "should not mutate the input!" do
          clean = "puts <<-FOO\nhi\nFOO\n"
          a = clean.dup
          Pry.new.valid_expression?(a)
          a.should == clean
        end
      end

      describe "history arrays" do
        it 'sets _ to the last result' do
          res   = []
          input = InputTester.new *[":foo", "self << _", "42", "self << _"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput)
          pry.repl(res)

          res.should == [:foo, 42]
        end

        it 'sets out to an array with the result' do
          res   = {}
          input = InputTester.new *[":foo", "42", "self[:res] = _out_"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput)
          pry.repl(res)

          res[:res].should.be.kind_of Pry::HistoryArray
          res[:res][1..2].should == [:foo, 42]
        end

        it 'sets _in_ to an array with the entered lines' do
          res   = {}
          input = InputTester.new *[":foo", "42", "self[:res] = _in_"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput)
          pry.repl(res)

          res[:res].should.be.kind_of Pry::HistoryArray
          res[:res][1..2].should == [":foo\n", "42\n"]
        end

        it 'uses 100 as the size of _in_ and _out_' do
          res   = []
          input = InputTester.new *["self << _out_.max_size << _in_.max_size"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput)
          pry.repl(res)

          res.should == [100, 100]
        end

        it 'can change the size of the history arrays' do
          res   = []
          input = InputTester.new *["self << _out_.max_size << _in_.max_size"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput,
                          :memory_size => 1000)
          pry.repl(res)

          res.should == [1000, 1000]
        end

        it 'store exceptions' do
          res   = []
          input = InputTester.new *["foo!","self << _in_[-1] << _out_[-1]"]
          pry   = Pry.new(:input => input, :output => Pry::NullOutput,
                          :memory_size => 1000)
          pry.repl(res)

          res.first.should == "foo!\n"
          res.last.should.be.kind_of NoMethodError
        end
      end

      describe "test loading rc files" do

        before do
          Pry.instance_variable_set(:@initial_session, true)
        end

        after do
          Pry::RC_FILES.clear
          Pry.config.should_load_rc = false
        end

        it "should run the rc file only once" do
          Pry.config.should_load_rc = true
          2.times { Pry::RC_FILES << File.expand_path("../testrc", __FILE__) }

          Pry.start(self, :input => StringIO.new("exit-all\n"), :output => Pry::NullOutput)
          TEST_RC.should == [0]

          Pry.start(self, :input => StringIO.new("exit-all\n"), :output => Pry::NullOutput)
          TEST_RC.should == [0]

          Object.remove_const(:TEST_RC)
        end

        it "should not run the rc file at all if Pry.config.should_load_rc is false" do
          Pry.config.should_load_rc = false
          Pry.start(self, :input => StringIO.new("exit-all\n"), :output => Pry::NullOutput)
          Object.const_defined?(:TEST_RC).should == false
        end

        it "should not load the rc file if #repl method invoked" do
          Pry.config.should_load_rc = true
          Pry.new(:input => StringIO.new("exit-all\n"), :output => Pry::NullOutput).repl(self)
          Object.const_defined?(:TEST_RC).should == false
          Pry.config.should_load_rc = false
        end

        describe "that raise exceptions" do
          before do
            Pry::RC_FILES << File.expand_path("../testrcbad", __FILE__)
            Pry.config.should_load_rc = true

            putsed = nil

            # YUCK! horrible hack to get round the fact that output is not configured
            # at the point this message is printed.
            (class << Pry; self; end).send(:define_method, :puts) { |str|
              putsed = str
            }

            @doing_it = lambda{
              Pry.start(self, :input => StringIO.new("Object::TEST_AFTER_RAISE=1\nexit-all\n"), :output => Pry::NullOutput)
              putsed
            }
          end

          after do
            Object.remove_const(:TEST_BEFORE_RAISE)
            Object.remove_const(:TEST_AFTER_RAISE)
            (class << Pry; undef_method :puts; end)
          end

          it "should not raise exceptions" do
            @doing_it.should.not.raise
          end

          it "should continue to run pry" do
            @doing_it[]
            Object.const_defined?(:TEST_BEFORE_RAISE).should == true
            Object.const_defined?(:TEST_AFTER_RAISE).should == true
          end

          it "should output an error" do
            @doing_it[].should =~ /Error loading #{File.expand_path("../testrcbad", __FILE__)}: messin with ya/
          end
        end
      end

      describe "nesting" do
        after do
          Pry.reset_defaults
          Pry.color = false
        end

        it 'should nest properly' do
          Pry.input = InputTester.new("cd 1", "cd 2", "cd 3", "\"nest:\#\{(_pry_.binding_stack.size - 1)\}\"", "exit-all")

          str_output = StringIO.new
          Pry.output = str_output

          o = Object.new

          pry_tester = o.pry
          str_output.string.should =~ /nest:3/
        end
      end

      describe "defining methods" do
        it 'should define a method on the singleton class of an object when performing "def meth;end" inside the object' do
          [Object.new, {}, []].each do |val|
            str_input = StringIO.new("def hello;end")
            Pry.new(:input => str_input, :output => StringIO.new).rep(val)

            val.methods(false).map(&:to_sym).include?(:hello).should == true
          end
        end

        it 'should define an instance method on the module when performing "def meth;end" inside the module' do
          str_input = StringIO.new("def hello;end")
          hello = Module.new
          Pry.new(:input => str_input, :output => StringIO.new).rep(hello)
          hello.instance_methods(false).map(&:to_sym).include?(:hello).should == true
        end

        it 'should define an instance method on the class when performing "def meth;end" inside the class' do
          str_input = StringIO.new("def hello;end")
          hello = Class.new
          Pry.new(:input => str_input, :output => StringIO.new).rep(hello)
          hello.instance_methods(false).map(&:to_sym).include?(:hello).should == true
        end

        it 'should define a method on the class of an object when performing "def meth;end" inside an immediate value or Numeric' do
          # should include  float in here, but test fails for some reason
          # on 1.8.7, no idea why!
          [:test, 0, true, false, nil].each do |val|
            str_input = StringIO.new("def hello;end")
            Pry.new(:input => str_input, :output => StringIO.new).rep(val)
            val.class.instance_methods(false).map(&:to_sym).include?(:hello).should == true
          end
        end
      end

      describe "commands" do
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

      describe "Object#pry" do

        after do
          Pry.reset_defaults
          Pry.color = false
        end

        it "should start a pry session on the receiver (first form)" do
          Pry.input = InputTester.new("self", "exit-all")

          str_output = StringIO.new
          Pry.output = str_output

          20.pry

          str_output.string.should =~ /20/
        end

        it "should start a pry session on the receiver (second form)" do
          Pry.input = InputTester.new("self", "exit-all")

          str_output = StringIO.new
          Pry.output = str_output

          pry 20

          str_output.string.should =~ /20/
        end

        it "should error if more than one argument is passed to Object#pry" do
          lambda { pry(20, :input => Readline) }.should.raise ArgumentError
        end
      end

      describe "Pry.binding_for" do
        it 'should return TOPLEVEL_BINDING if parameter self is main' do
          _main_ = lambda { TOPLEVEL_BINDING.eval('self') }
          Pry.binding_for(_main_.call).is_a?(Binding).should == true
          Pry.binding_for(_main_.call).should == TOPLEVEL_BINDING
          Pry.binding_for(_main_.call).should == Pry.binding_for(_main_.call)
        end
      end


      describe "test Pry defaults" do

        after do
          Pry.reset_defaults
          Pry.color = false
        end

        describe "input" do

          after do
            Pry.reset_defaults
            Pry.color = false
          end

          it 'should set the input default, and the default should be overridable' do
            Pry.input = InputTester.new("5")

            str_output = StringIO.new
            Pry.output = str_output
            Pry.new.rep
            str_output.string.should =~ /5/

            Pry.new(:input => InputTester.new("6")).rep
            str_output.string.should =~ /6/
          end

          it 'should pass in the prompt if readline arity is 1' do
            Pry.prompt = proc { "A" }

            arity_one_input = Class.new do
              attr_accessor :prompt
              def readline(prompt)
                @prompt = prompt
                "exit-all"
              end
            end.new

            Pry.start(self, :input => arity_one_input, :output => Pry::NullOutput)
            arity_one_input.prompt.should == Pry.prompt.call
          end

          it 'should not pass in the prompt if the arity is 0' do
            Pry.prompt = proc { "A" }

            arity_zero_input = Class.new do
              def readline
                "exit-all"
              end
            end.new

            lambda { Pry.start(self, :input => arity_zero_input, :output => Pry::NullOutput) }.should.not.raise Exception
          end

          it 'should not pass in the prompt if the arity is -1' do
            Pry.prompt = proc { "A" }

            arity_multi_input = Class.new do
              attr_accessor :prompt

              def readline(*args)
                @prompt = args.first
                "exit-all"
              end
            end.new

            Pry.start(self, :input => arity_multi_input, :output => Pry::NullOutput)
            arity_multi_input.prompt.should == nil
          end

        end

        it 'should set the output default, and the default should be overridable' do
          Pry.input = InputTester.new("5", "6", "7")

          str_output = StringIO.new
          Pry.output = str_output

          Pry.new.rep
          str_output.string.should =~ /5/

          Pry.new.rep
          str_output.string.should =~ /5\n.*6/

          str_output2 = StringIO.new
          Pry.new(:output => str_output2).rep
          str_output2.string.should.not =~ /5\n.*6/
          str_output2.string.should =~ /7/
        end

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

            it 'should inherit "help" command from Pry::CommandBase' do
              klass = Pry::CommandSet.new do
                command "h", "h command" do
                end
              end

              klass.commands.keys.size.should == 3
              klass.commands.keys.include?("help").should == true
              klass.commands.keys.include?("install-command").should == true
              klass.commands.keys.include?("h").should == true
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
                alias_command "help2", "help"
              end
              klass.commands["help2"].block.should == klass.commands["help"].block
            end

            it 'should change description of a command using desc' do
              klass = Pry::CommandSet.new do; end
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
              str_output.string.rstrip.should == "help to the music"


              Pry.reset_defaults
              Pry.color = false
            end
          end

          it "should set the print default, and the default should be overridable" do
            new_print = proc { |out, value| out.puts value }
            Pry.print =  new_print

            Pry.new.print.should == Pry.print
            str_output = StringIO.new
            Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
            str_output.string.should == "test\n"

            str_output = StringIO.new
            Pry.new(:input => InputTester.new("\"test\""), :output => str_output,
                    :print => proc { |out, value| out.puts value.reverse }).rep
            str_output.string.should == "tset\n"

            Pry.new.print.should == Pry.print
            str_output = StringIO.new
            Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
            str_output.string.should == "test\n"
          end

          describe "pry return values" do
            it 'should return the target object' do
              Pry.start(self, :input => StringIO.new("exit-all"), :output => Pry::NullOutput).should == self
            end

            it 'should return the parameter given to exit-all' do
              Pry.start(self, :input => StringIO.new("exit-all 10"), :output => Pry::NullOutput).should == 10
            end

            it 'should return the parameter (multi word string) given to exit-all' do
              Pry.start(self, :input => StringIO.new("exit-all \"john mair\""), :output => Pry::NullOutput).should == "john mair"
            end

            it 'should return the parameter (function call) given to exit-all' do
              Pry.start(self, :input => StringIO.new("exit-all 'abc'.reverse"), :output => Pry::NullOutput).should == 'cba'
            end

            it 'should return the parameter (self) given to exit-all' do
              Pry.start("carl", :input => StringIO.new("exit-all self"), :output => Pry::NullOutput).should == "carl"
            end
          end

          describe "prompts" do
            it 'should set the prompt default, and the default should be overridable (single prompt)' do
              new_prompt = proc { "test prompt> " }
              Pry.prompt =  new_prompt

              Pry.new.prompt.should == Pry.prompt
              Pry.new.select_prompt(true, 0).should == "test prompt> "
              Pry.new.select_prompt(false, 0).should == "test prompt> "

              new_prompt = proc { "A" }
              pry_tester = Pry.new(:prompt => new_prompt)
              pry_tester.prompt.should == new_prompt
              pry_tester.select_prompt(true, 0).should == "A"
              pry_tester.select_prompt(false, 0).should == "A"

              Pry.new.prompt.should == Pry.prompt
              Pry.new.select_prompt(true, 0).should == "test prompt> "
              Pry.new.select_prompt(false, 0).should == "test prompt> "
            end

            it 'should set the prompt default, and the default should be overridable (multi prompt)' do
              new_prompt = [proc { "test prompt> " }, proc { "test prompt* " }]
              Pry.prompt =  new_prompt

              Pry.new.prompt.should == Pry.prompt
              Pry.new.select_prompt(true, 0).should == "test prompt> "
              Pry.new.select_prompt(false, 0).should == "test prompt* "

              new_prompt = [proc { "A" }, proc { "B" }]
              pry_tester = Pry.new(:prompt => new_prompt)
              pry_tester.prompt.should == new_prompt
              pry_tester.select_prompt(true, 0).should == "A"
              pry_tester.select_prompt(false, 0).should == "B"

              Pry.new.prompt.should == Pry.prompt
              Pry.new.select_prompt(true, 0).should == "test prompt> "
              Pry.new.select_prompt(false, 0).should == "test prompt* "
            end

            describe 'storing and restoring the prompt' do
              before do
                make = lambda do |name,i|
                  prompt = [ proc { "#{i}>" } , proc { "#{i+1}>" } ]
                  (class << prompt; self; end).send(:define_method, :inspect) { "<Prompt-#{name}>" }
                  prompt
                end
                @a , @b , @c = make[:a,0] , make[:b,1] , make[:c,2]
                @pry = Pry.new :prompt => @a
              end
              it 'should have a prompt stack' do
                @pry.push_prompt @b
                @pry.push_prompt @c
                @pry.prompt.should == @c
                @pry.pop_prompt
                @pry.prompt.should == @b
                @pry.pop_prompt
                @pry.prompt.should == @a
              end

              it 'should restore overridden prompts when returning from file-mode' do
                pry = Pry.new :input => InputTester.new('shell-mode', 'shell-mode'),
                :prompt => [ proc { 'P>' } ] * 2
                pry.select_prompt(true, 0).should == "P>"
                pry.re
                pry.select_prompt(true, 0).should =~ /\Apry .* \$ \z/
                pry.re
                pry.select_prompt(true, 0).should == "P>"
              end

              it '#pop_prompt should return the popped prompt' do
                @pry.push_prompt @b
                @pry.push_prompt @c
                @pry.pop_prompt.should == @c
                @pry.pop_prompt.should == @b
              end

              it 'should not pop the last prompt' do
                @pry.push_prompt @b
                @pry.pop_prompt.should == @b
                @pry.pop_prompt.should == @a
                @pry.pop_prompt.should == @a
                @pry.prompt.should == @a
              end

              describe '#prompt= should replace the current prompt with the new prompt' do
                it 'when only one prompt on the stack' do
                  @pry.prompt = @b
                  @pry.prompt.should == @b
                  @pry.pop_prompt.should == @b
                  @pry.pop_prompt.should == @b
                end
                it 'when several prompts on the stack' do
                  @pry.push_prompt @b
                  @pry.prompt = @c
                  @pry.pop_prompt.should == @c
                  @pry.pop_prompt.should == @a
                end
              end
            end
          end

          describe "view_clip used for displaying an object in a truncated format" do

            VC_MAX_LENGTH = 60

            describe "given an object with an #inspect string" do
              it "returns the #<> format of the object (never use inspect)" do
                o = Object.new
                def o.inspect; "a" * VC_MAX_LENGTH; end

                Pry.view_clip(o, VC_MAX_LENGTH).should =~ /#<Object/
              end
            end

            describe "given the 'main' object" do
              it "returns the #to_s of main (special case)" do
                o = TOPLEVEL_BINDING.eval('self')
                Pry.view_clip(o, VC_MAX_LENGTH).should == o.to_s
              end
            end

            describe "given the a Numeric, String or Symbol object" do
              [1, 2.0, -5, "hello", :test].each do |o|
                it "returns the #inspect of the special-cased immediate object: #{o}" do
                  Pry.view_clip(o, VC_MAX_LENGTH).should == o.inspect
                end
              end

              # only testing with String here :)
              it "returns #<> format of the special-cased immediate object if #inspect is longer than maximum" do
                o = "o" * (VC_MAX_LENGTH + 1)
                Pry.view_clip(o, VC_MAX_LENGTH).should =~ /#<String/
              end
            end

            describe "given an object with an #inspect string as long as the maximum specified" do
              it "returns the #<> format of the object (never use inspect)" do
                o = Object.new
                def o.inspect; "a" * VC_MAX_LENGTH; end

                Pry.view_clip(o, VC_MAX_LENGTH).should =~ /#<Object/
              end
            end

            describe "given a regular object with an #inspect string longer than the maximum specified" do

              describe "when the object is a regular one" do
                it "returns a string of the #<class name:object idish> format" do
                  o = Object.new
                  def o.inspect; "a" * (VC_MAX_LENGTH + 1); end

                  Pry.view_clip(o, VC_MAX_LENGTH).should =~ /#<Object/
                end
              end

              describe "when the object is a Class or a Module" do
                describe "without a name (usually a c = Class.new)" do
                  it "returns a string of the #<class name:object idish> format" do
                    c, m = Class.new, Module.new

                    Pry.view_clip(c, VC_MAX_LENGTH).should =~ /#<Class/
                    Pry.view_clip(m, VC_MAX_LENGTH).should =~ /#<Module/
                  end
                end

                describe "with a #name longer than the maximum specified" do
                  it "returns a string of the #<class name:object idish> format" do
                    c, m = Class.new, Module.new


                    def c.name; "a" * (VC_MAX_LENGTH + 1); end
                    def m.name; "a" * (VC_MAX_LENGTH + 1); end

                    Pry.view_clip(c, VC_MAX_LENGTH).should =~ /#<Class/
                    Pry.view_clip(m, VC_MAX_LENGTH).should =~ /#<Module/
                  end
                end

                describe "with a #name shorter than or equal to the maximum specified" do
                  it "returns a string of the #<class name:object idish> format" do
                    c, m = Class.new, Module.new

                    def c.name; "a" * VC_MAX_LENGTH; end
                    def m.name; "a" * VC_MAX_LENGTH; end

                    Pry.view_clip(c, VC_MAX_LENGTH).should == c.name
                    Pry.view_clip(m, VC_MAX_LENGTH).should == m.name
                  end
                end

              end

            end

          end

          it 'should set the hooks default, and the default should be overridable' do
            Pry.input = InputTester.new("exit-all")
            Pry.hooks = {
              :before_session => proc { |out,_,_| out.puts "HELLO" },
              :after_session => proc { |out,_,_| out.puts "BYE" }
            }

            str_output = StringIO.new
            Pry.new(:output => str_output).repl
            str_output.string.should =~ /HELLO/
            str_output.string.should =~ /BYE/

            Pry.input.rewind

            str_output = StringIO.new
            Pry.new(:output => str_output,
                    :hooks => {
                      :before_session => proc { |out,_,_| out.puts "MORNING" },
                      :after_session => proc { |out,_,_| out.puts "EVENING" }
                    }
                    ).repl

            str_output.string.should =~ /MORNING/
            str_output.string.should =~ /EVENING/

            # try below with just defining one hook
            Pry.input.rewind
            str_output = StringIO.new
            Pry.new(:output => str_output,
                    :hooks => {
                      :before_session => proc { |out,_,_| out.puts "OPEN" }
                    }
                    ).repl

            str_output.string.should =~ /OPEN/

            Pry.input.rewind
            str_output = StringIO.new
            Pry.new(:output => str_output,
                    :hooks => {
                      :after_session => proc { |out,_,_| out.puts "CLOSE" }
                    }
                    ).repl

            str_output.string.should =~ /CLOSE/

            Pry.reset_defaults
            Pry.color = false
          end
        end
      end
    end
  end
