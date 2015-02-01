require_relative 'helper'

_version = 1

describe "test Pry defaults" do
  before do
    @str_output = StringIO.new
  end

  after do
    Pry.reset_defaults
    Pry.config.color = false
  end

  describe "input" do
    after do
      Pry.reset_defaults
      Pry.config.color = false
    end

    it 'should set the input default, and the default should be overridable' do
      Pry.config.input = InputTester.new("5")
      Pry.config.output = @str_output
      Object.new.pry
      @str_output.string.should =~ /5/

      Pry.config.output = @str_output
      Object.new.pry :input => InputTester.new("6")
      @str_output.string.should =~ /6/
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

      Pry.start(self, :input => arity_one_input, :output => StringIO.new)
      arity_one_input.prompt.should eq Pry.prompt.call
    end

    it 'should not pass in the prompt if the arity is 0' do
      Pry.prompt = proc { "A" }

      arity_zero_input = Class.new do
        def readline
          "exit-all"
        end
      end.new

      expect { Pry.start(self, :input => arity_zero_input, :output => StringIO.new) }.to_not raise_error
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

      Pry.start(self, :input => arity_multi_input, :output => StringIO.new)
      arity_multi_input.prompt.should eq nil
    end

  end

  it 'should set the output default, and the default should be overridable' do
    Pry.config.output = @str_output

    Pry.config.input  = InputTester.new("5")
    Object.new.pry
    @str_output.string.should =~ /5/

    Pry.config.input  = InputTester.new("6")
    Object.new.pry
    @str_output.string.should =~ /5\n.*6/

    Pry.config.input  = InputTester.new("7")
    @str_output = StringIO.new
    Object.new.pry :output => @str_output
    @str_output.string.should_not =~ /5\n.*6/
    @str_output.string.should =~ /7/
  end

  it "should set the print default, and the default should be overridable" do
    new_print = proc { |out, value| out.puts "=> LOL" }
    Pry.config.print =  new_print

    Pry.new.print.should eq Pry.config.print
    Object.new.pry :input => InputTester.new("\"test\""), :output => @str_output
    @str_output.string.should eq "=> LOL\n"

    @str_output = StringIO.new
    Object.new.pry :input => InputTester.new("\"test\""), :output => @str_output,
                   :print => proc { |out, value| out.puts value.reverse }
    @str_output.string.should eq "tset\n"

    Pry.new.print.should eq Pry.config.print
    @str_output = StringIO.new
    Object.new.pry :input => InputTester.new("\"test\""), :output => @str_output
    @str_output.string.should eq "=> LOL\n"
  end

  describe "pry return values" do
    it 'should return nil' do
      Pry.start(self, :input => StringIO.new("exit-all"), :output => StringIO.new).should eq nil
    end

    it 'should return the parameter given to exit-all' do
      Pry.start(self, :input => StringIO.new("exit-all 10"), :output => StringIO.new).should eq 10
    end

    it 'should return the parameter (multi word string) given to exit-all' do
      Pry.start(self, :input => StringIO.new("exit-all \"john mair\""), :output => StringIO.new).should eq "john mair"
    end

    it 'should return the parameter (function call) given to exit-all' do
      Pry.start(self, :input => StringIO.new("exit-all 'abc'.reverse"), :output => StringIO.new).should eq 'cba'
    end

    it 'should return the parameter (self) given to exit-all' do
      Pry.start("carl", :input => StringIO.new("exit-all self"), :output => StringIO.new).should eq "carl"
    end
  end

  describe "prompts" do
    before do
      Pry.config.output = StringIO.new
    end

    def get_prompts(pry)
      a = pry.select_prompt
      pry.eval "["
      b = pry.select_prompt
      pry.eval "]"
      [a, b]
    end

    it 'should set the prompt default, and the default should be overridable (single prompt)' do
      Pry.prompt = proc { "test prompt> " }
      new_prompt = proc { "A" }

      pry = Pry.new
      pry.prompt.should eq Pry.prompt
      get_prompts(pry).should eq ["test prompt> ",  "test prompt> "]


      pry = Pry.new(:prompt => new_prompt)
      pry.prompt.should eq new_prompt
      get_prompts(pry).should eq ["A",  "A"]

      pry = Pry.new
      pry.prompt.should eq Pry.prompt
      get_prompts(pry).should eq ["test prompt> ",  "test prompt> "]
    end

    it 'should set the prompt default, and the default should be overridable (multi prompt)' do
      Pry.prompt = [proc { "test prompt> " }, proc { "test prompt* " }]
      new_prompt = [proc { "A" }, proc { "B" }]

      pry = Pry.new
      pry.prompt.should eq Pry.prompt
      get_prompts(pry).should eq ["test prompt> ",  "test prompt* "]


      pry = Pry.new(:prompt => new_prompt)
      pry.prompt.should eq new_prompt
      get_prompts(pry).should eq ["A",  "B"]

      pry = Pry.new
      pry.prompt.should eq Pry.prompt
      get_prompts(pry).should eq ["test prompt> ",  "test prompt* "]
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
        @pry.prompt.should eq @c
        @pry.pop_prompt
        @pry.prompt.should eq @b
        @pry.pop_prompt
        @pry.prompt.should eq @a
      end

      it 'should restore overridden prompts when returning from file-mode' do
        pry = Pry.new(:prompt => [ proc { 'P>' } ] * 2)
        pry.select_prompt.should eq "P>"
        pry.process_command('shell-mode')
        pry.select_prompt.should =~ /\Apry .* \$ \z/
        pry.process_command('shell-mode')
        pry.select_prompt.should eq "P>"
      end

      it '#pop_prompt should return the popped prompt' do
        @pry.push_prompt @b
        @pry.push_prompt @c
        @pry.pop_prompt.should eq @c
        @pry.pop_prompt.should eq @b
      end

      it 'should not pop the last prompt' do
        @pry.push_prompt @b
        @pry.pop_prompt.should eq @b
        @pry.pop_prompt.should eq @a
        @pry.pop_prompt.should eq @a
        @pry.prompt.should eq @a
      end

      describe '#prompt= should replace the current prompt with the new prompt' do
        it 'when only one prompt on the stack' do
          @pry.prompt = @b
          @pry.prompt.should eq @b
          @pry.pop_prompt.should eq @b
          @pry.pop_prompt.should eq @b
        end
        it 'when several prompts on the stack' do
          @pry.push_prompt @b
          @pry.prompt = @c
          @pry.pop_prompt.should eq @c
          @pry.pop_prompt.should eq @a
        end
      end
    end
  end

  describe "view_clip used for displaying an object in a truncated format" do
    DEFAULT_OPTIONS =  {
      max_length: 60
    }
    MAX_LENGTH = DEFAULT_OPTIONS[:max_length]

    describe "given an object with an #inspect string" do
      it "returns the #<> format of the object (never use inspect)" do
        o = Object.new
        def o.inspect; "a" * MAX_LENGTH; end

        Pry.view_clip(o, DEFAULT_OPTIONS).should =~ /#<Object/
      end
    end

    describe "given the 'main' object" do
      it "returns the #to_s of main (special case)" do
        o = TOPLEVEL_BINDING.eval('self')
        Pry.view_clip(o, DEFAULT_OPTIONS).should eq o.to_s
      end
    end

    describe "the list of prompt safe objects" do
      [1, 2.0, -5, "hello", :test].each do |o|
        it "returns the #inspect of the special-cased immediate object: #{o}" do
          Pry.view_clip(o, DEFAULT_OPTIONS).should eq o.inspect
        end
      end

      it "returns #<> format of the special-cased immediate object if #inspect is longer than maximum" do
        o = "o" * (MAX_LENGTH + 1)
        Pry.view_clip(o, DEFAULT_OPTIONS).should =~ /#<String/
      end

      it "returns the #inspect of the custom prompt safe objects" do
        Barbie = Class.new { def inspect; "life is plastic, it's fantastic" end }
        Pry.config.prompt_safe_objects << Barbie
        output = Pry.view_clip(Barbie.new, DEFAULT_OPTIONS)
        output.should eq "life is plastic, it's fantastic"
      end
    end

    describe "given an object with an #inspect string as long as the maximum specified" do
      it "returns the #<> format of the object (never use inspect)" do
        o = Object.new
        def o.inspect; "a" * DEFAULT_OPTIONS; end

        Pry.view_clip(o, DEFAULT_OPTIONS).should =~ /#<Object/
      end
    end

    describe "given a regular object with an #inspect string longer than the maximum specified" do

      describe "when the object is a regular one" do
        it "returns a string of the #<class name:object idish> format" do
          o = Object.new
          def o.inspect; "a" * (DEFAULT_OPTIONS + 1); end

          Pry.view_clip(o, DEFAULT_OPTIONS).should =~ /#<Object/
        end
      end

      describe "when the object is a Class or a Module" do
        describe "without a name (usually a c = Class.new)" do
          it "returns a string of the #<class name:object idish> format" do
            c, m = Class.new, Module.new

            Pry.view_clip(c, DEFAULT_OPTIONS).should =~ /#<Class/
            Pry.view_clip(m, DEFAULT_OPTIONS).should =~ /#<Module/
          end
        end

        describe "with a #name longer than the maximum specified" do
          it "returns a string of the #<class name:object idish> format" do
            c, m = Class.new, Module.new


            def c.name; "a" * (MAX_LENGTH + 1); end
            def m.name; "a" * (MAX_LENGTH + 1); end

            Pry.view_clip(c, DEFAULT_OPTIONS).should =~ /#<Class/
            Pry.view_clip(m, DEFAULT_OPTIONS).should =~ /#<Module/
          end
        end

        describe "with a #name shorter than or equal to the maximum specified" do
          it "returns a string of the #<class name:object idish> format" do
            c, m = Class.new, Module.new

            def c.name; "a" * MAX_LENGTH; end
            def m.name; "a" * MAX_LENGTH; end

            Pry.view_clip(c, DEFAULT_OPTIONS).should eq c.name
            Pry.view_clip(m, DEFAULT_OPTIONS).should eq m.name
          end
        end

      end

    end

  end

  describe 'quiet' do
    it 'should show whereami by default' do
      Pry.start(binding, :input => InputTester.new("1", "exit-all"),
              :output => @str_output,
              :hooks => Pry::DEFAULT_HOOKS)

      @str_output.string.should =~ /[w]hereami by default/
    end

    it 'should hide whereami if quiet is set' do
      Pry.new(:input => InputTester.new("exit-all"),
              :output => @str_output,
              :quiet => true,
              :hooks => Pry::DEFAULT_HOOKS)

      @str_output.string.should eq ""
    end
  end

  describe 'toplevel_binding' do
    it 'should be devoid of local variables' do
      pry_eval(Pry.toplevel_binding, "ls -l").should_not =~ /_version/
    end

    it 'should have self the same as TOPLEVEL_BINDING' do
      Pry.toplevel_binding.eval('self').should.equal? TOPLEVEL_BINDING.eval('self')
    end

    # https://github.com/rubinius/rubinius/issues/1779
    unless Pry::Helpers::BaseHelpers.rbx?
      it 'should define private methods on Object' do
        TOPLEVEL_BINDING.eval 'def gooey_fooey; end'
        method(:gooey_fooey).owner.should eq Object
        Pry::Method(method(:gooey_fooey)).visibility.should eq :private
      end
    end
  end

  it 'should set the hooks default, and the default should be overridable' do
    Pry.config.input = InputTester.new("exit-all")
    Pry.config.hooks = Pry::Hooks.new.
      add_hook(:before_session, :my_name) { |out,_,_|  out.puts "HELLO" }.
      add_hook(:after_session, :my_name) { |out,_,_| out.puts "BYE" }

    Object.new.pry :output => @str_output
    @str_output.string.should =~ /HELLO/
    @str_output.string.should =~ /BYE/

    Pry.config.input.rewind

    @str_output = StringIO.new
    Object.new.pry :output => @str_output,
                   :hooks => Pry::Hooks.new.
                   add_hook( :before_session, :my_name) { |out,_,_| out.puts "MORNING" }.
                   add_hook(:after_session, :my_name) { |out,_,_| out.puts "EVENING" }

    @str_output.string.should =~ /MORNING/
    @str_output.string.should =~ /EVENING/

    # try below with just defining one hook
    Pry.config.input.rewind
    @str_output = StringIO.new
    Object.new.pry :output => @str_output,
                   :hooks => Pry::Hooks.new.
                   add_hook(:before_session, :my_name) { |out,_,_| out.puts "OPEN" }

    @str_output.string.should =~ /OPEN/

    Pry.config.input.rewind
    @str_output = StringIO.new
    Object.new.pry :output => @str_output,
                   :hooks => Pry::Hooks.new.
                   add_hook(:after_session, :my_name) { |out,_,_| out.puts "CLOSE" }

    @str_output.string.should =~ /CLOSE/

    Pry.reset_defaults
    Pry.config.color = false
  end
end
