# frozen_string_literal: true

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
    # Silence deprecation warnings.
    before { allow(Kernel).to receive(:warn) }

    it 'should set the input default, and the default should be overridable' do
      Pry.config.input = InputTester.new("5")
      Pry.config.output = @str_output
      Object.new.pry
      expect(@str_output.string).to match(/5/)

      Pry.config.output = @str_output
      Object.new.pry input: InputTester.new("6")
      expect(@str_output.string).to match(/6/)
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

      Pry.start(self, input: arity_one_input, output: StringIO.new)
      expect(arity_one_input.prompt).to eq Pry.prompt.call
    end

    it 'should not pass in the prompt if the arity is 0' do
      Pry.prompt = proc { "A" }

      arity_zero_input = Class.new do
        def readline
          "exit-all"
        end
      end.new

      expect { Pry.start(self, input: arity_zero_input, output: StringIO.new) }
        .to_not raise_error
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

      Pry.start(self, input: arity_multi_input, output: StringIO.new)
      expect(arity_multi_input.prompt).to eq nil
    end
  end

  it 'should set the output default, and the default should be overridable' do
    Pry.config.output = @str_output

    Pry.config.input  = InputTester.new("5")
    Object.new.pry
    expect(@str_output.string).to match(/5/)

    Pry.config.input = InputTester.new("6")
    Object.new.pry
    expect(@str_output.string).to match(/5\n.*6/)

    Pry.config.input = InputTester.new("7")
    @str_output = StringIO.new
    Object.new.pry output: @str_output
    expect(@str_output.string).not_to match(/5\n.*6/)
    expect(@str_output.string).to match(/7/)
  end

  it "should set the print default, and the default should be overridable" do
    new_print = proc { |out, _value| out.puts "=> LOL" }
    Pry.config.print = new_print

    expect(Pry.new.print).to eq Pry.config.print
    Object.new.pry input: InputTester.new("\"test\""), output: @str_output
    expect(@str_output.string).to eq "=> LOL\n"

    @str_output = StringIO.new
    Object.new.pry input: InputTester.new("\"test\""), output: @str_output,
                   print: proc { |out, value| out.puts value.reverse }
    expect(@str_output.string).to eq "tset\n"

    expect(Pry.new.print).to eq Pry.config.print
    @str_output = StringIO.new
    Object.new.pry input: InputTester.new("\"test\""), output: @str_output
    expect(@str_output.string).to eq "=> LOL\n"
  end

  describe "pry return values" do
    it 'should return nil' do
      expect(Pry.start(self, input: StringIO.new("exit-all"), output: StringIO.new))
        .to eq nil
    end

    it 'should return the parameter given to exit-all' do
      expect(Pry.start(self, input: StringIO.new("exit-all 10"), output: StringIO.new))
        .to eq 10
    end

    it 'should return the parameter (multi word string) given to exit-all' do
      input = StringIO.new("exit-all \"john mair\"")
      expect(Pry.start(self, input: input, output: StringIO.new)).to eq "john mair"
    end

    it 'should return the parameter (function call) given to exit-all' do
      input = StringIO.new("exit-all 'abc'.reverse")
      expect(Pry.start(self, input: input, output: StringIO.new)).to eq 'cba'
    end

    it 'should return the parameter (self) given to exit-all' do
      pry = Pry.start(
        "carl", input: StringIO.new("exit-all self"), output: StringIO.new
      )
      expect(pry).to eq "carl"
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

    it 'sets the prompt default, and the default should be overridable (single prompt)' do
      Pry.prompt = Pry::Prompt.new(:test, '', Array.new(2) { proc { '>' } })
      new_prompt = Pry::Prompt.new(:new_test, '', Array.new(2) { proc { 'A' } })

      pry = Pry.new
      expect(pry.prompt).to eq Pry.prompt
      expect(get_prompts(pry)).to eq(%w[> >])

      pry = Pry.new(prompt: new_prompt)
      expect(pry.prompt).to eq(new_prompt)
      expect(get_prompts(pry)).to eq(%w[A A])

      pry = Pry.new
      expect(pry.prompt).to eq Pry.prompt
      expect(get_prompts(pry)).to eq(%w[> >])
    end

    it 'sets the prompt default, and the default should be overridable (multi prompt)' do
      Pry.prompt = Pry::Prompt.new(:test, '', [proc { '>' }, proc { '*' }])
      new_prompt = Pry::Prompt.new(:new_test, '', [proc { 'A' }, proc { 'B' }])

      pry = Pry.new
      expect(pry.prompt).to eq Pry.prompt
      expect(get_prompts(pry)).to eq(%w[> *])

      pry = Pry.new(prompt: new_prompt)
      expect(pry.prompt).to eq(new_prompt)
      expect(get_prompts(pry)).to eq(%w[A B])

      pry = Pry.new
      expect(pry.prompt).to eq(Pry.prompt)
      expect(get_prompts(pry)).to eq(%w[> *])
    end

    describe 'storing and restoring the prompt' do
      let(:prompt1) { Pry::Prompt.new(:test1, '', Array.new(2) { proc { '' } }) }
      let(:prompt2) { Pry::Prompt.new(:test2, '', Array.new(2) { proc { '' } }) }
      let(:prompt3) { Pry::Prompt.new(:test3, '', Array.new(2) { proc { '' } }) }

      let(:pry) { Pry.new(prompt: prompt1) }

      it 'should have a prompt stack' do
        pry.push_prompt(prompt2)
        pry.push_prompt(prompt3)
        expect(pry.prompt).to eq(prompt3)
        pry.pop_prompt
        expect(pry.prompt).to match(prompt2)
        pry.pop_prompt
        expect(pry.prompt).to eq(prompt1)
      end

      it 'should restore overridden prompts when returning from shell-mode' do
        pry = Pry.new(
          prompt: Pry::Prompt.new(:test, '', Array.new(2) { proc { 'P>' } })
        )
        expect(pry.select_prompt).to eq('P>')
        pry.process_command('shell-mode')
        expect(pry.select_prompt).to match(/\Apry .* \$ \z/)
        pry.process_command('shell-mode')
        expect(pry.select_prompt).to eq('P>')
      end

      it '#pop_prompt should return the popped prompt' do
        pry.push_prompt(prompt2)
        pry.push_prompt(prompt3)
        expect(pry.pop_prompt).to eq(prompt3)
        expect(pry.pop_prompt).to eq(prompt2)
      end

      it 'should not pop the last prompt' do
        pry.push_prompt(prompt2)
        expect(pry.pop_prompt).to eq(prompt2)
        expect(pry.pop_prompt).to eq(prompt1)
        expect(pry.pop_prompt).to eq(prompt1)
        expect(pry.prompt).to eq(prompt1)
      end

      describe '#prompt= should replace the current prompt with the new prompt' do
        it 'when only one prompt on the stack' do
          pry.prompt = prompt2
          expect(pry.prompt).to eq(prompt2)
          expect(pry.pop_prompt).to eq(prompt2)
          expect(pry.pop_prompt).to eq(prompt2)
        end

        it 'when several prompts on the stack' do
          pry.push_prompt(prompt2)
          pry.prompt = prompt3
          expect(pry.pop_prompt).to eq(prompt3)
          expect(pry.pop_prompt).to eq(prompt1)
        end
      end
    end
  end

  describe "view_clip used for displaying an object in a truncated format" do
    before do
      stub_const('DEFAULT_OPTIONS', max_length: 60)
      stub_const('MAX_LENGTH', 60)
    end

    describe "given an object with an #inspect string" do
      it "returns the #<> format of the object (never use inspect)" do
        o = Object.new
        def o.inspect
          "a" * MAX_LENGTH
        end

        expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to match(/#<Object/)
      end
    end

    describe "given the 'main' object" do
      it "returns the #to_s of main (special case)" do
        o = TOPLEVEL_BINDING.eval('self')
        expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to eq o.to_s
      end
    end

    describe "the list of prompt safe objects" do
      [1, 2.0, -5, "hello", :test].each do |o|
        it "returns the #inspect of the special-cased immediate object: #{o}" do
          expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to eq o.inspect
        end
      end

      it(
        "returns #<> format of the special-cased immediate object if " \
        "#inspect is longer than maximum"
      ) do
        o = "o" * (MAX_LENGTH + 1)
        expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to match(/#<String/)
      end

      it "returns the #inspect of the custom prompt safe objects" do
        Barbie = Class.new do
          def inspect
            "life is plastic, it's fantastic"
          end
        end
        Pry.config.prompt_safe_contexts << Barbie
        output = Pry.view_clip(Barbie.new, DEFAULT_OPTIONS)
        expect(output).to eq "life is plastic, it's fantastic"
      end
    end

    describe "given an object with an #inspect string as long as the maximum specified" do
      it "returns the #<> format of the object (never use inspect)" do
        o = Object.new
        def o.inspect
          "a" * DEFAULT_OPTIONS
        end

        expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to match(/#<Object/)
      end
    end

    describe(
      "given a regular object with an #inspect string longer than the maximum specified"
    ) do
      describe "when the object is a regular one" do
        it "returns a string of the #<class name:object idish> format" do
          o = Object.new
          def o.inspect
            "a" * (DEFAULT_OPTIONS + 1)
          end

          expect(Pry.view_clip(o, DEFAULT_OPTIONS)).to match(/#<Object/)
        end
      end

      describe "when the object is a Class or a Module" do
        describe "without a name (usually a c = Class.new)" do
          it "returns a string of the #<class name:object idish> format" do
            c = Class.new
            m = Module.new

            expect(Pry.view_clip(c, DEFAULT_OPTIONS)).to match(/#<Class/)
            expect(Pry.view_clip(m, DEFAULT_OPTIONS)).to match(/#<Module/)
          end
        end

        describe "with a #name longer than the maximum specified" do
          it "returns a string of the #<class name:object idish> format" do
            c = Class.new
            m = Module.new

            def c.name
              "a" * (MAX_LENGTH + 1)
            end

            def m.name
              "a" * (MAX_LENGTH + 1)
            end

            expect(Pry.view_clip(c, DEFAULT_OPTIONS)).to match(/#<Class/)
            expect(Pry.view_clip(m, DEFAULT_OPTIONS)).to match(/#<Module/)
          end
        end

        describe "with a #name shorter than or equal to the maximum specified" do
          it "returns a string of the #<class name:object idish> format" do
            c = Class.new
            m = Module.new

            def c.name
              "a" * MAX_LENGTH
            end

            def m.name
              "a" * MAX_LENGTH
            end

            expect(Pry.view_clip(c, DEFAULT_OPTIONS)).to eq c.name
            expect(Pry.view_clip(m, DEFAULT_OPTIONS)).to eq m.name
          end
        end
      end
    end
  end

  describe 'quiet' do
    it 'should show whereami by default' do
      Pry.start(
        binding,
        input: InputTester.new("1", "exit-all"),
        output: @str_output,
        hooks: Pry::Config.new.hooks
      )

      expect(@str_output.string).to match(/[w]hereami by default/)
    end

    it 'should hide whereami if quiet is set' do
      Pry.new(
        input: InputTester.new('exit-all'),
        output: @str_output,
        quiet: true,
        hooks: Pry::Config.new.hooks
      )

      expect(@str_output.string).to eq ""
    end
  end

  describe 'toplevel_binding' do
    it 'should be devoid of local variables' do
      expect(pry_eval(Pry.toplevel_binding, "ls -l")).not_to match(/_version/)
    end

    it 'should have self the same as TOPLEVEL_BINDING' do
      expect(Pry.toplevel_binding.eval('self')).to equal(TOPLEVEL_BINDING.eval('self'))
    end

    it 'should define private methods on Object' do
      TOPLEVEL_BINDING.eval 'def gooey_fooey; end'
      expect(method(:gooey_fooey).owner).to eq Object
      expect(Pry::Method(method(:gooey_fooey)).visibility).to eq :private
    end
  end

  it 'should set the hooks default, and the default should be overridable' do
    Pry.config.input = InputTester.new("exit-all")
    Pry.config.hooks = Pry::Hooks.new
      .add_hook(:before_session, :my_name) { |out, _, _| out.puts "HELLO" }
      .add_hook(:after_session, :my_name) { |out, _, _| out.puts "BYE" }

    Object.new.pry output: @str_output
    expect(@str_output.string).to match(/HELLO/)
    expect(@str_output.string).to match(/BYE/)

    Pry.config.input.rewind

    @str_output = StringIO.new
    hooks = Pry::Hooks.new
      .add_hook(:before_session, :my_name) { |out, _, _| out.puts "MORNING" }
      .add_hook(:after_session, :my_name) { |out, _, _| out.puts "EVENING" }
    Object.new.pry(output: @str_output, hooks: hooks)

    expect(@str_output.string).to match(/MORNING/)
    expect(@str_output.string).to match(/EVENING/)

    # try below with just defining one hook
    Pry.config.input.rewind
    @str_output = StringIO.new
    hooks = Pry::Hooks.new
      .add_hook(:before_session, :my_name) { |out, _, _| out.puts "OPEN" }
    Object.new.pry(output: @str_output, hooks: hooks)

    expect(@str_output.string).to match(/OPEN/)

    Pry.config.input.rewind
    @str_output = StringIO.new
    hooks = Pry::Hooks.new
      .add_hook(:after_session, :my_name) { |out, _, _| out.puts "CLOSE" }
    Object.new.pry(output: @str_output, hooks: hooks)

    expect(@str_output.string).to match(/CLOSE/)

    Pry.reset_defaults
    Pry.config.color = false
  end
end
