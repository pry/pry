# frozen_string_literal: true

RSpec.describe Pry::Helpers::CommandHelpers do
  describe "#temp_file" do
    it "yields a tempfile" do
      expect { |block| subject.temp_file(&block) }
        .to yield_with_args(an_instance_of(Tempfile))
    end

    it "creates a tempfile with rb extension" do
      subject.temp_file do |file|
        expect(file.path).to end_with('.rb')
      end
    end

    it "allows overwriting file extension" do
      subject.temp_file('.clj') do |file|
        expect(file.path).to end_with('.clj')
      end
    end

    it "closes the tempfile" do
      tempfile = nil
      subject.temp_file('.clj') do |file|
        tempfile = file
      end
      expect(tempfile).to be_closed
    end

    it "unlinks the tempfile" do
      tempfile = nil
      subject.temp_file('.clj') do |file|
        tempfile = file
      end
      expect(tempfile.path).to be_nil
    end
  end

  describe "#internal_binding?" do
    context "when target's __method__ returns __binding__" do
      it "returns true" do
        expect(subject.internal_binding?(Object.__binding__)).to be_truthy
      end
    end

    context "when target's __method__ returns __pry__" do
      it "returns true" do
        expect(subject.internal_binding?(Object.new.__binding__)).to be_truthy
      end
    end

    context "when target's __method__ returns nil" do
      it "returns true" do
        expect(subject.internal_binding?(TOPLEVEL_BINDING)).to be_falsey
      end
    end
  end

  describe "#get_method_or_raise" do
    subject do
      Class.new do
        class << self
          include Pry::Helpers::CommandHelpers

          def command_name
            'test-command'
          end

          def pry_instance
            Pry.new
          end

          def target
            binding
          end
        end
      end
    end

    context "when there's name but no corresponding method" do
      it "raises MethodNotFound" do
        expect { subject.get_method_or_raise('foobar', binding) }
          .to raise_error(Pry::MethodNotFound, /method.+could not be found/)
      end
    end

    context "when super opt is provided but there's no super method" do
      let(:test_binding) do
        def test_method; end
        binding
      end

      it "raises MethodNotFound" do
        expect { subject.get_method_or_raise('test_method', test_binding, super: 1) }
          .to raise_error(Pry::MethodNotFound, /has no super method/)
      end
    end

    context "when super opt is provided and there's a parent method" do
      let(:test_binding) do
        ParentClass = Class.new do
          def test_method
            :parent
          end
        end

        ChildClass = Class.new(ParentClass) do
          def test_method
            :child
          end
        end

        binding
      end

      it "gets the parent method" do
        method = subject.get_method_or_raise(
          'ChildClass#test_method', test_binding, super: 1
        )
        expect(method.owner).to eq(ParentClass)
      end
    end

    context "when there's no method name" do
      it "raises MethodNotFound" do
        expect { subject.get_method_or_raise(nil, binding) }
          .to raise_error(Pry::MethodNotFound, /no method name given/)
      end
    end
  end

  describe "#unindent" do
    it "removes the same prefix from all lines" do
      expect(subject.unindent(" one\n two\n")).to eq("one\ntwo\n")
    end

    it "should not be phased by empty lines" do
      expect(subject.unindent(" one\n\n two\n")).to eq("one\n\ntwo\n")
    end

    it "should only remove a common prefix" do
      expect(subject.unindent("  one\n two\n")).to eq(" one\ntwo\n")
    end

    it "should also remove tabs if present" do
      expect(subject.unindent("\tone\n\ttwo\n")).to eq("one\ntwo\n")
    end

    it "should ignore lines starting with --" do
      expect(subject.unindent(" one\n--\n two\n")).to eq("one\n--\ntwo\n")
    end
  end

  describe "#restrict_to_lines" do
    context "when lines are specified as an integer" do
      it "restricts the given string to the specified line number" do
        expect(subject.restrict_to_lines("one\ntwo\n\three\nfour\n", 2))
          .to eq("two\n")
      end
    end

    context "when lines are specified as a range" do
      it "restricts the given string to the specified range" do
        expect(subject.restrict_to_lines("one\ntwo\n\three\nfour\n", 2...3))
          .to eq("two\n\three\n")
      end
    end
  end

  describe "#one_index_number" do
    context "when line number is more than 0" do
      it "decrements the line number" do
        expect(subject.one_index_number(2)).to eq(1)
      end
    end

    context "when line number is 0" do
      it "returns the line number" do
        expect(subject.one_index_number(0)).to eq(0)
      end
    end
  end

  describe "#one_index_range" do
    it "decrements range boundaries" do
      expect(subject.one_index_range(3..30)).to eq(2..29)
    end
  end

  describe "#one_index_range_or_number" do
    context "when given an integer" do
      it "decrements the line number" do
        expect(subject.one_index_range_or_number(2)).to eq(1)
      end
    end

    context "when given a range" do
      it "decrements range boundaries" do
        expect(subject.one_index_range_or_number(3..30)).to eq(2..29)
      end
    end
  end

  describe "#absolute_index_number" do
    context "when line number is zero" do
      it "returns the line number" do
        expect(subject.absolute_index_number(0, 1)).to eq(0)
      end
    end

    context "when line number is less than zero" do
      it "returns the absolute sum of line number and array length" do
        expect(subject.absolute_index_number(-2, 5)).to eq(3)
      end
    end
  end

  describe "#absolute_index_range" do
    context "when given an integer" do
      it "returns a range based on the integer and array length" do
        expect(subject.absolute_index_range(1, 2)).to eq(1..1)
      end
    end

    context "when given an integer" do
      it "returns an absolute range that was decremented" do
        expect(subject.absolute_index_range(-3..-20, 22)).to eq(19..2)
      end
    end
  end

  describe "#set_file_and_dir_locals" do
    let(:pry_instance) { Pry.new }
    let(:context) { binding }

    it "injects local variable _file_" do
      subject.set_file_and_dir_locals('foo/test.rb', pry_instance, context)
      expect(context.eval('_file_')).to end_with('test.rb')
    end

    it "injects local variable _dir_" do
      subject.set_file_and_dir_locals('foo/test.rb', pry_instance, context)
      expect(context.eval('_dir_')).to end_with('foo')
    end

    it "sets pry instance's last_file to _file_" do
      subject.set_file_and_dir_locals('foo/test.rb', pry_instance, context)
      expect(pry_instance.last_file).to end_with('test.rb')
    end

    it "sets pry instance's last_dir to _dir_" do
      subject.set_file_and_dir_locals('foo/test.rb', pry_instance, context)
      expect(pry_instance.last_dir).to end_with('foo')
    end
  end
end
