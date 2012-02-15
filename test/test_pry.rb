require 'helper'

describe Pry do

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
        input_string = "Command"
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

      describe "complete_expression?" do
        it "should not mutate the input!" do
          clean = "puts <<-FOO\nhi\nFOO\n"
          a = clean.dup
          Pry.new.complete_expression?(a)
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

      describe "last_result" do
        it "should be set to the most recent value" do
          mock_pry("2", "_ + 82").should =~ /84/
        end

        it "should be set to the result of a command with :keep_retval" do
          mock_pry("Pry::Commands.block_command '++', '', {:keep_retval => true} do |a| a.to_i + 1; end", '++ 86', '++ #{_}').should =~ /88/
        end

        it "should be preserved over an empty line" do
          mock_pry("2 + 2", " ", "\t",  " ", "_ + 92").should =~ /96/
        end

        it "should be preserved when evalling a  command without :keep_retval" do
          mock_pry("2 + 2", "ls -l", "_ + 96").should =~ /100/
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

        it "should not load the pryrc if it cannot expand ENV[HOME]" do
          old_home = ENV['HOME']
          old_rc = Pry.config.should_load_rc
          ENV['HOME'] = nil
          Pry.config.should_load_rc = true
          lambda { Pry.start(self, :input => StringIO.new("exit-all\n"), :output => Pry::NullOutput) }.should.not.raise

          ENV['HOME'] = old_home
          Pry.config.should_load_rc = old_rc
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
    end
  end

  describe 'setting custom options' do
    it 'should not raise for unrecognized options' do
      should.not.raise?(NoMethodError) {
        instance = Pry.new(:custom_option => 'custom value')
      }
    end
  end
end
