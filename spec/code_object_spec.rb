# frozen_string_literal: true

RSpec.describe Pry::CodeObject do
  let(:pry) do
    Pry.new.tap { |p| p.binding_stack = [binding] }
  end

  describe ".lookup" do
    context "when looking up method" do
      let(:pry) do
        obj = Class.new.new
        def obj.foo_method; end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      it "finds methods defined on objects" do
        code_object = described_class.lookup('obj.foo_method', pry)
        expect(code_object).to be_a(Pry::Method)
        expect(code_object.name).to eq('foo_method')
      end
    end

    context "when looking up modules" do
      module FindMeModule; end

      after { Object.remove_const(:FindMeModule) }

      it "finds modules" do
        code_object = described_class.lookup('FindMeModule', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up classes" do
      class FindMeClass; end

      after { Object.remove_const(:FindMeClass) }

      it "finds classes" do
        code_object = described_class.lookup('FindMeClass', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up procs" do
      let(:test_proc) { proc { :hello } }

      it "finds classes" do
        code_object = described_class.lookup('test_proc', pry)
        expect(code_object).to be_a(Pry::Method)
        expect(code_object.wrapped.call).to eql(test_proc)
      end
    end

    context "when looking up Pry::BlockCommand" do
      let(:pry) do
        pry = Pry.new
        pry.commands.command('test-block-command') {}
        pry.binding_stack = [binding]
        pry
      end

      it "finds Pry:BlockCommand" do
        code_object = described_class.lookup('test-block-command', pry)
        expect(code_object.command_name).to eq('test-block-command')
      end
    end

    context "when looking up Pry::ClassCommand" do
      class TestClassCommand < Pry::ClassCommand
        match 'test-class-command'
      end

      let(:pry) do
        pry = Pry.new
        pry.commands.add_command(TestClassCommand)
        pry.binding_stack = [binding]
        pry
      end

      after { Object.remove_const(:TestClassCommand) }

      it "finds Pry:BlockCommand" do
        code_object = described_class.lookup('test-class-command', pry)
        expect(code_object.command_name).to eq('test-class-command')
      end
    end

    context "when looking up Pry commands by class" do
      class TestCommand < Pry::ClassCommand
        match 'test-command'
      end

      let(:pry) do
        pry = Pry.new
        pry.commands.add_command(TestCommand)
        pry.binding_stack = [binding]
        pry
      end

      after { Object.remove_const(:TestCommand) }

      it "finds Pry::WrappedModule" do
        code_object = described_class.lookup('TestCommand', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up Pry commands by listing" do
      let(:pry) do
        pry = Pry.new
        pry.commands.command('test-command', listing: 'test-listing') {}
        pry.binding_stack = [binding]
        pry
      end

      it "finds Pry::WrappedModule" do
        code_object = described_class.lookup('test-listing', pry)
        expect(code_object.command_name).to eq('test-listing')
      end
    end

    context "when looking up 'nil'" do
      it "returns nil" do
        pry = Pry.new
        pry.binding_stack = [binding]

        code_object = described_class.lookup(nil, pry)
        expect(code_object).to be_nil
      end
    end

    context "when looking up 'nil' while being inside a module" do
      let(:pry) do
        Pry.new.tap { |p| p.binding_stack = [Pry.binding_for(Module)] }
      end

      it "infers the module" do
        code_object = described_class.lookup(nil, pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up empty string while being inside a module" do
      let(:pry) do
        Pry.new.tap { |p| p.binding_stack = [Pry.binding_for(Module)] }
      end

      it "infers the module" do
        code_object = described_class.lookup('', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up 'nil' while being inside a class instance" do
      let(:pry) do
        Pry.new.tap { |p| p.binding_stack = [Pry.binding_for(Module.new)] }
      end

      it "infers the module" do
        code_object = described_class.lookup(nil, pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up empty string while being inside a class instance" do
      let(:pry) do
        Pry.new.tap { |p| p.binding_stack = [Pry.binding_for(Module.new)] }
      end

      it "infers the module" do
        code_object = described_class.lookup('', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up 'nil' while being inside a method" do
      let(:pry) do
        klass = Class.new do
          def test_binding
            binding
          end
        end

        Pry.new.tap { |p| p.binding_stack = [klass.new.test_binding] }
      end

      it "infers the method" do
        code_object = described_class.lookup(nil, pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up empty string while being inside a method" do
      let(:pry) do
        klass = Class.new do
          def test_binding
            binding
          end
        end

        Pry.new.tap { |p| p.binding_stack = [klass.new.test_binding] }
      end

      it "infers the method" do
        code_object = described_class.lookup('', pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up instance methods of a class" do
      let(:pry) do
        instance = Class.new do
          def instance_method; end
        end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      it "finds instance methods" do
        code_object = described_class.lookup('instance#instance_method', pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up instance methods" do
      let(:pry) do
        instance = Class.new do
          def instance_method; end
        end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      it "finds instance methods via the # notation" do
        code_object = described_class.lookup('instance#instance_method', pry)
        expect(code_object).to be_a(Pry::Method)
      end

      it "finds instance methods via the . notation" do
        code_object = described_class.lookup('instance.instance_method', pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up anonymous class methods" do
      let(:pry) do
        klass = Class.new do
          def self.class_method; end
        end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      it "finds instance methods via the # notation" do
        code_object = described_class.lookup('klass.class_method', pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up class methods of a named class" do
      before do
        class TestClass
          def self.class_method; end
        end
      end

      after { Object.remove_const(:TestClass) }

      it "finds instance methods via the # notation" do
        code_object = described_class.lookup('TestClass.class_method', pry)
        expect(code_object).to be_a(Pry::Method)
      end
    end

    context "when looking up classes by names of variables" do
      let(:pry) do
        klass = Class.new

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      it "finds instance methods via the # notation" do
        code_object = described_class.lookup('klass', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end
    end

    context "when looking up classes with 'super: 0'" do
      let(:pry) do
        class ParentClass; end
        class ChildClass < ParentClass; end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      after do
        Object.remove_const(:ChildClass)
        Object.remove_const(:ParentClass)
      end

      it "finds the child class" do
        code_object = described_class.lookup('ChildClass', pry, super: 0)
        expect(code_object).to be_a(Pry::WrappedModule)
        expect(code_object.wrapped).to eq(ChildClass)
      end
    end

    context "when looking up classes with 'super: 1'" do
      let(:pry) do
        class ParentClass; end
        class ChildClass < ParentClass; end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      after do
        Object.remove_const(:ChildClass)
        Object.remove_const(:ParentClass)
      end

      it "finds the parent class" do
        code_object = described_class.lookup('ChildClass', pry, super: 1)
        expect(code_object).to be_a(Pry::WrappedModule)
        expect(code_object.wrapped).to eq(ParentClass)
      end
    end

    context "when looking up commands with the super option" do
      let(:pry) do
        pry = Pry.new
        pry.commands.command('test-command') {}
        pry.binding_stack = [binding]
        pry
      end

      it "finds the command ignoring the super option" do
        code_object = described_class.lookup('test-command', pry, super: 1)
        expect(code_object.command_name).to eq('test-command')
      end
    end

    context "when there is a class and a method who is a namesake" do
      let(:pry) do
        class TestClass
          class InnerTestClass; end
        end
        def TestClass; end

        Pry.new.tap { |p| p.binding_stack = [binding] }
      end

      after { Object.remove_const(:TestClass) }

      it "finds the class before the method" do
        code_object = described_class.lookup('TestClass', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
      end

      it "finds the method when the look up ends with ()" do
        code_object = described_class.lookup('TestClass()', pry)
        expect(code_object).to be_a(Pry::Method)
      end

      it "finds the class before the method when it's namespaced" do
        code_object = described_class.lookup('TestClass::InnerTestClass', pry)
        expect(code_object).to be_a(Pry::WrappedModule)
        expect(code_object.wrapped).to eq(TestClass::InnerTestClass)
      end
    end
  end
end
