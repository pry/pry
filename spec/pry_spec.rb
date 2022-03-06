# frozen_string_literal: true

describe Pry do
  before do
    @str_output = StringIO.new
  end

  describe ".configure" do
    it "yields a block with Pry.config as its argument" do
      Pry.config.foo = nil
      Pry.configure do |config|
        config.foo = "bar"
      end
      expect(Pry.config.foo).to eq("bar")
    end
  end

  describe "Exotic object support" do
    # regression test for exotic object support
    it "Should not error when return value is a BasicObject instance" do
      ReplTester.start do
        expect(input('BasicObject.new')).to match(/^=> #<BasicObject:/)
      end
    end
  end

  describe 'DISABLE_PRY' do
    before do
      allow(Pry::Env).to receive(:[])
      allow(Pry::Env).to receive(:[]).with('DISABLE_PRY').and_return(true)
    end

    it 'should not binding.pry' do
      expect(binding.pry).to eq nil # rubocop:disable Lint/Debugger
    end

    it 'should not Pry.start' do
      expect(Pry.start).to eq nil
    end
  end

  describe 'FAIL_PRY' do
    before do
      allow(Pry::Env).to receive(:[])
      allow(Pry::Env).to receive(:[]).with('FAIL_PRY').and_return(true)
    end

    it 'should raise an error for binding.pry' do
      expect { binding.pry }.to raise_error(RuntimeError) # rubocop:disable Lint/Debugger
    end

    it 'should raise an error for Pry.start' do
      expect { Pry.start }.to raise_error(RuntimeError)
    end
  end

  describe "Pry.critical_section" do
    it "should prevent Pry being called" do
      output = StringIO.new
      Pry.config.output = output
      Pry.critical_section do
        Pry.start
      end
      expect(output.string).to match(/Pry started inside Pry/)
    end
  end

  describe "Pry.binding_for" do
    # regression test for burg's bug (see git history)
    it "Should not error when object doesn't have a valid == method" do
      o = Object.new
      def o.==(_other)
        raise
      end

      expect { Pry.binding_for(o) }.to_not raise_error
    end

    it "should not leak local variables" do
      [Object.new, Array, 3].each do |obj|
        expect(Pry.binding_for(obj).eval("local_variables")).to be_empty
      end
    end

    it "should work on frozen objects" do
      a = "hello".freeze
      expect(Pry.binding_for(a).eval("self")).to equal(a)
    end
  end

  describe "#last_exception=" do
    before do
      @pry = Pry.new binding: binding
      @e = mock_exception "foo.rb:1"
    end

    it "returns an instance of Pry::LastException" do
      @pry.last_exception = @e
      expect(@pry.last_exception.wrapped_exception).to eq @e
    end

    it "returns a frozen exception" do
      @pry.last_exception = @e.freeze
      expect(@pry.last_exception).to be_frozen
    end

    it "returns an object who mirrors itself as the wrapped exception" do
      @pry.last_exception = @e.freeze
      expect(@pry.last_exception).to be_an_instance_of StandardError
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

      # bug fix for https://github.com/pry/pry/issues/93
      it 'should not leak pry constants into Object namespace' do
        expect { pry_eval(Object.new, "Command") }.to raise_error NameError
      end

      it 'should be able to operate inside the BasicObject class' do
        pry_eval(BasicObject, ":foo", "Pad.obj = _")
        expect(Pad.obj).to eq :foo
      end

      it 'should set an ivar on an object' do
        o = Object.new
        pry_eval(o, "@x = 10")
        expect(o.instance_variable_get(:@x)).to eq 10
      end

      it 'should display error if Pry instance runs out of input' do
        redirect_pry_io(StringIO.new, @str_output) do
          Pry.start
        end
        expect(@str_output.string).to match(/Error: Pry ran out of things to read/)
      end

      it 'should make self evaluate to the receiver of the rep session' do
        o = :john
        expect(pry_eval(o, "self")).to eq o
      end

      it 'should define a nested class under Hello and not on top-level or Pry' do
        mock_pry(Pry.binding_for(Hello), "class Nested", "end")
        expect(Hello.const_defined?(:Nested)).to eq true
      end

      it(
        'should suppress output if input ends in a ";" and is an Exception ' \
        'object (single line)'
      ) do
        expect(mock_pry("Exception.new;")).to eq ""
      end

      it 'should suppress output if input ends in a ";" (single line)' do
        expect(mock_pry("x = 5;")).to eq ""
      end

      it 'should be able to evaluate exceptions normally' do
        was_called = false
        mock_pry("RuntimeError.new", exception_handler: proc { was_called = true })
        expect(was_called).to eq false
      end

      it 'should notice when exceptions are raised' do
        was_called = false
        mock_pry("raise RuntimeError", exception_handler: proc { was_called = true })
        expect(was_called).to eq true
      end

      it 'should not try to catch intended exceptions' do
        expect { mock_pry("raise SystemExit") }.to raise_error SystemExit
        # SIGTERM
        expect { mock_pry("raise SignalException.new(15)") }
          .to raise_error SignalException
      end

      describe "inside signal handler" do
        before do
          unless Signal.list.key?('USR1')
            skip "Host OS #{RbConfig::CONFIG['host_os']} doesn't support signal USR1"
          end

          if Pry::Helpers::Platform.jruby?
            skip "jruby allows mutex usage in signal handlers"
          end

          if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.0.0")
            skip "pre-2.0 mri allows mutex usage in signal handlers"
          end

          trap("USR1") { @str_output = mock_pry }
        end

        after do
          trap("USR1") do
            # do nothing
          end
        end

        it "should return with error message" do
          Process.kill("USR1", Process.pid)
          expect(@str_output).to match(/Unable to obtain mutex lock/)
        end
      end

      describe "multi-line input" do
        it "works" do
          expect(mock_pry('x = ', '1 + 4')).to match(/5/)
        end

        it 'should suppress output if input ends in a ";" (multi-line)' do
          expect(mock_pry('def self.blah', ':test', 'end;')).to eq ''
        end

        describe "newline stripping from an empty string" do
          it "with double quotes" do
            expect(mock_pry('"', '"')).to match(/"\\n"/)
            expect(mock_pry('"', "\n", "\n", "\n", '"')).to match(/"\\n\\n\\n\\n"/)
          end

          it "with single quotes" do
            expect(mock_pry("'", "'")).to match(/"\\n"/)
            expect(mock_pry("'", "\n", "\n", "\n", "'")).to match(/"\\n\\n\\n\\n"/)
          end

          it "with fancy delimiters" do
            expect(mock_pry('%(', ')')).to match(/"\\n"/)
            expect(mock_pry('%|', "\n", "\n", '|')).to match(/"\\n\\n\\n"/)
            expect(mock_pry('%q[', "\n", "\n", ']')).to match(/"\\n\\n\\n"/)
          end
        end

        describe "newline stripping from an empty regexp" do
          it "with regular regexp delimiters" do
            expect(mock_pry('/', '/')).to match(%r{/\n/})
          end

          it "with fancy delimiters" do
            expect(mock_pry('%r{', "\n", "\n", '}')).to match(%r{/\n\n\n/})
            expect(mock_pry('%r<', "\n", '>')).to match(%r{/\n\n/})
          end
        end

        describe "newline from an empty heredoc" do
          it "works" do
            expect(mock_pry('<<HERE', 'HERE')).to match(/""/)
            expect(mock_pry("<<'HERE'", "\n", 'HERE')).to match(/"\\n"/)
            expect(mock_pry("<<-'HERE'", "\n", "\n", 'HERE')).to match(/"\\n\\n"/)
          end
        end
      end
    end

    describe "repl" do
      describe "basic functionality" do
        it 'should set an ivar on an object and exit the repl' do
          input_strings = ["@x = 10", "exit-all"]
          input = InputTester.new(*input_strings)

          o = Object.new

          Pry.start(o, input: input, output: StringIO.new)

          expect(o.instance_variable_get(:@x)).to eq 10
        end
      end

      describe "complete_expression?" do
        it "should not mutate the input!" do
          clean = "puts <<-FOO\nhi\nFOO\n"
          a = clean.dup
          Pry::Code.complete_expression?(a)
          expect(a).to eq clean
        end
      end

      describe "history arrays" do
        it 'sets _ to the last result' do
          t = pry_tester
          t.eval ":foo"
          expect(t.eval("_")).to eq :foo
          t.eval "42"
          expect(t.eval("_")).to eq 42
        end

        it 'sets out to an array with the result' do
          t = pry_tester
          t.eval ":foo"
          t.eval "42"
          res = t.eval "_out_"

          expect(res).to be_a_kind_of(Pry::Ring)
          expect(res[1..2]).to eq [:foo, 42]
        end

        it 'sets _in_ to an array with the entered lines' do
          t = pry_tester
          t.eval ":foo"
          t.eval "42"
          res = t.eval "_in_"

          expect(res).to be_a_kind_of(Pry::Ring)
          expect(res[1..2]).to eq [":foo\n", "42\n"]
        end

        it 'uses 100 as the size of _in_ and _out_' do
          expect(pry_tester.eval("[_in_.max_size, _out_.max_size]")).to eq [100, 100]
        end

        it 'can change the size of the history arrays' do
          expect(pry_tester(memory_size: 1000).eval("[_out_, _in_].map(&:max_size)"))
            .to eq [1000, 1000]
        end

        it 'store exceptions' do
          mock_pry("foo!", "Pad.in = _in_[-1]; Pad.out = _out_[-1]")

          expect(Pad.in).to eq "foo!\n"
          expect(Pad.out).to be_a_kind_of NoMethodError
        end
      end

      describe "last_result" do
        it "should be set to the most recent value" do
          expect(pry_eval("2", "_ + 82")).to eq 84
        end

        # This test needs mock_pry because the command retvals work by
        # replacing the eval_string, so _ won't be modified without Pry doing
        # a REPL loop.
        it "should be set to the result of a command with :keep_retval" do
          Pry::Commands.block_command '++', '', keep_retval: true do |a|
            a.to_i + 1
          end

          # rubocop:disable Lint/InterpolationCheck
          expect(mock_pry('++ 86', '++ #{_}')).to match(/88/)
          # rubocop:enable Lint/InterpolationCheck
        end

        it "should be preserved over an empty line" do
          expect(pry_eval("2 + 2", " ", "\t",  " ", "_ + 92")).to eq 96
        end

        it "should be preserved when evalling a  command without :keep_retval" do
          expect(pry_eval("2 + 2", "ls -l", "_ + 96")).to eq 100
        end
      end

      describe "nesting" do
        after do
          Pry.reset_defaults
          Pry.config.color = false
        end

        it 'should nest properly' do
          Pry.config.input = InputTester.new(
            "cd 1", "cd 2", "cd 3",
            "\"nest:\#\{(pry_instance.binding_stack.size - 1)\}\"", "exit-all"
          )

          Pry.config.output = @str_output

          o = Object.new
          o.pry

          expect(@str_output.string).to match(/nest:3/)
        end
      end

      describe "defining methods" do
        it(
          'defines a method on the singleton class of an object when performing ' \
          '"def meth;end" inside the object'
        ) do
          [Object.new, {}, []].each do |val|
            pry_eval(val, 'def hello; end')
            expect(val.methods(false).map(&:to_sym).include?(:hello)).to eq true
          end
        end

        it(
          'defines an instance method on the module when performing ' \
          '"def meth;end" inside the module'
        ) do
          hello = Module.new
          pry_eval(hello, "def hello; end")
          expect(hello.instance_methods(false).map(&:to_sym).include?(:hello))
            .to be_truthy
        end

        it(
          'defines an instance method on the class when performing ' \
          '"def meth;end" inside the class'
        ) do
          hello = Class.new
          pry_eval(hello, "def hello; end")
          expect(hello.instance_methods(false).map(&:to_sym).include?(:hello))
            .to be_truthy
        end

        it(
          'defines a method on the class of an object when performing ' \
          '"def meth;end" inside an immediate value or Numeric'
        ) do
          # JRuby behaves different than CRuby here (seems it always has to some
          # extent, see 'unless' below). It didn't seem trivial to work
          # around. Skip for now.
          skip "JRuby incompatibility" if Pry::Helpers::Platform.jruby?
          [
            :test, 0, true, false, nil, (0.0 unless Pry::Helpers::Platform.jruby?)
          ].each do |val|
            pry_eval(val, "def hello; end")
            expect(val.class.instance_methods(false).map(&:to_sym).include?(:hello))
              .to be_truthy
          end
        end
      end

      describe "Object#pry" do
        after do
          Pry.reset_defaults
          Pry.config.color = false
        end

        it "should start a pry session on the receiver (first form)" do
          Pry.config.input = InputTester.new("self", "exit-all")

          str_output = StringIO.new
          Pry.config.output = str_output

          20.pry

          expect(str_output.string).to match(/20/)
        end

        it "should start a pry session on the receiver (second form)" do
          Pry.config.input = InputTester.new("self", "exit-all")

          str_output = StringIO.new
          Pry.config.output = str_output

          pry 20

          expect(str_output.string).to match(/20/)
        end

        it "should raise if more than two arguments are passed to Object#pry" do
          expect { pry(20, :quiet, input: Readline) }.to raise_error ArgumentError
        end
      end

      describe "Pry.binding_for" do
        it 'should return TOPLEVEL_BINDING if parameter self is main' do
          main = -> { TOPLEVEL_BINDING.eval('self') }
          expect(Pry.binding_for(main.call).is_a?(Binding)).to eq true
          expect(Pry.binding_for(main.call)).to eq TOPLEVEL_BINDING
          expect(Pry.binding_for(main.call)).to eq Pry.binding_for(main.call)
        end
      end
    end
  end

  describe 'setting custom options' do
    it 'does not raise for unrecognized options' do
      expect { Pry.new(custom_option: 'custom value') }.to_not raise_error
    end

    it 'correctly handles the :quiet option (#1261)' do
      instance = Pry.new(quiet: true)
      expect(instance.quiet?).to eq true
    end
  end

  describe "a fresh instance" do
    it "should use `caller` as its backtrace" do
      location  = "#{__FILE__}:#{__LINE__ + 1}"[1..-1] # omit leading .
      backtrace = Pry.new.backtrace

      expect(backtrace).not_to equal nil
      expect(backtrace.any? { |l| l.include?(location) }).to equal true
    end
  end
end
