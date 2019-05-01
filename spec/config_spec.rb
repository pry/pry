RSpec.describe Pry::Config do
  specify { expect(subject.input).to respond_to(:readline) }
  specify { expect(subject.output).to be_an(IO) }
  specify { expect(subject.commands).to be_a(Pry::CommandSet) }
  specify { expect(subject.prompt_name).to be_a(String) }
  specify { expect(subject.prompt).to be_a(Pry::Prompt) }
  specify { expect(subject.prompt_safe_contexts).to be_an(Array) }
  specify { expect(subject.print).to be_a(Method) }
  specify { expect(subject.quiet).to be(true).or be(false) }
  specify { expect(subject.exception_handler).to be_a(Method) }
  specify { expect(subject.unrescued_exceptions).to be_an(Array) }
  specify { expect(subject.hooks).to be_a(Pry::Hooks) }
  specify { expect(subject.pager).to be(true).or be(false) }
  specify { expect(subject.system).to be_a(Method) }
  specify { expect(subject.color).to be(true).or be(false) }
  specify { expect(subject.default_window_size).to be_a(Numeric) }
  specify { expect(subject.editor).to be_a(String) }
  specify { expect(subject.should_load_rc).to be(true).or be(false) }
  specify { expect(subject.should_load_local_rc).to be(true).or be(false) }
  specify { expect(subject.should_trap_interrupts).to be(true).or be(false) }
  specify { expect(subject.disable_auto_reload).to be(true).or be(false) }
  specify { expect(subject.command_prefix).to be_a(String) }
  specify { expect(subject.auto_indent).to be(true).or be(false) }
  specify { expect(subject.correct_indent).to be(true).or be(false) }
  specify { expect(subject.collision_warning).to be(true).or be(false) }
  specify { expect(subject.output_prefix).to be_a(String) }
  specify { expect(subject.requires).to be_an(Array) }
  specify { expect(subject.should_load_requires).to be(true).or be(false) }
  specify { expect(subject.should_load_plugins).to be(true).or be(false) }
  specify { expect(subject.windows_console_warning).to be(true).or be(false) }
  specify { expect(subject.control_d_handler).to be_a(Method) }
  specify { expect(subject.memory_size).to be_a(Numeric) }
  specify { expect(subject.extra_sticky_locals).to be_a(Hash) }
  specify { expect(subject.command_completions).to be_a(Proc) }
  specify { expect(subject.file_completions).to be_a(Proc) }
  specify { expect(subject.ls).to be_an(OpenStruct) }
  specify { expect(subject.completer).to eq(Pry::InputCompleter) }
  specify { expect(subject.history).to be_a(Pry::History) }
  specify { expect(subject.history_save).to eq(true).or be(false) }
  specify { expect(subject.history_load).to eq(true).or be(false) }
  specify { expect(subject.history_file).to be_a(String) }
  specify { expect(subject.exec_string).to be_a(String) }

  describe "#merge!" do
    it "merges given hash with the config instance" do
      subject.merge!(output_prefix: '~> ', exec_string: '!')

      expect(subject.output_prefix).to eq('~> ')
      expect(subject.exec_string).to eq('!')
    end

    it "returns self" do
      config = subject.merge!(output_prefix: '~> ')
      expect(subject).to eql(config)
    end

    context "when an undefined option is given" do
      it "adds the option to the config" do
        subject.merge!(new_option: 1, other_option: 2)

        expect(subject.new_option).to eq(1)
        expect(subject.other_option).to eq(2)
      end
    end
  end

  describe "#merge" do
    it "returns a new config object" do
      expect(subject).not_to equal(subject.merge(new_option: 1, other_option: 2))
    end

    it "doesn't mutate the original config" do
      subject.merge(new_option: 1, other_option: 2)

      expect(subject).not_to respond_to(:new_option)
      expect(subject).not_to respond_to(:other_option)
    end
  end

  describe "#method_missing" do
    context "when invoked method ends with =" do
      it "assigns a new custom option" do
        subject.foo = 1
        expect(subject.foo).to eq(1)
      end
    end

    context "when invoked method is not an option" do
      it "raises NoMethodError" do
        expect { subject.foo }.to raise_error(NoMethodError)
      end
    end

    context "when invoked method is a LazyValue" do
      it "defines a callable attribute" do
        subject.foo = Pry::Config::LazyValue.new { 1 }
        expect(subject.foo).to eq(1)
      end
    end
  end

  describe "#respond_to?" do
    context "when checking an undefined option" do
      it "returns false" do
        expect(subject.respond_to?(:foo)).to be(false)
      end
    end

    context "when checking a defined option" do
      before { subject.foo = 1 }

      it "returns true for the reader" do
        expect(subject.respond_to?(:foo)).to be(true)
      end

      it "returns true for the writer" do
        expect(subject.respond_to?(:foo=)).to be(true)
      end
    end
  end

  describe "#[]" do
    it "reads the config value" do
      expect_any_instance_of(Pry::Config::Value).to receive(:call)
      subject[:foo] = 1
      subject[:foo]
    end

    it "returns the config value" do
      subject[:foo] = 1
      expect(subject[:foo]).to eq(1)
    end
  end
end
