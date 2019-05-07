# frozen_string_literal: true

describe Pry::WrappedModule do
  describe "#initialize" do
    it "should raise an exception when a non-module is passed" do
      expect { Pry::WrappedModule.new(nil) }.to raise_error ArgumentError
    end
  end

  describe "candidates" do
    class Host
      %w[spec/fixtures/candidate_helper1.rb
         spec/fixtures/candidate_helper2.rb].each do |file|
        binding.eval(File.read(file), file, 1) # rubocop:disable Security/Eval
      end

      # rank 2
      class CandidateTest
        def test6; end
      end

      class PitifullyBlank
        DEFAULT_TEST = CandidateTest
      end

      FOREVER_ALONE_LINE = __LINE__ + 1
      class ForeverAlone
        class DoublyNested
          # nested docs
          class TriplyNested
            def nested_method; end
          end
        end
      end
    end

    describe "number_of_candidates" do
      it 'should return the correct number of candidates' do
        expect(Pry::WrappedModule(Host::CandidateTest).number_of_candidates).to eq 3
      end

      it 'should return 0 candidates for a class with no nested modules or methods' do
        expect(Pry::WrappedModule(Host::PitifullyBlank).number_of_candidates).to eq 0
      end

      it 'should return 1 candidate for a class with a nested module with methods' do
        expect(Pry::WrappedModule(Host::ForeverAlone).number_of_candidates).to eq 1
      end
    end

    describe "ordering of candidates" do
      it 'should return class with largest number of methods as primary candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(0).file)
          .to match(/helper1/)
      end

      it(
        'returns class with second largest number of methods as second ranked candidate'
      ) do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(1).file)
          .to match(/helper2/)
      end

      it 'returns class with third largest number of methods as third ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(2).file)
          .to match(/#{__FILE__}/)
      end

      it 'should raise when trying to access non-existent candidate' do
        expect { Pry::WrappedModule(Host::CandidateTest).candidate(3) }
          .to raise_error Pry::CommandError
      end
    end

    describe "source_location" do
      it 'should return primary candidates source_location by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        expect(wm.source_location).to eq wm.candidate(0).source_location
      end

      it 'returns the location of the outer module if an inner module has methods' do
        wm = Pry::WrappedModule(Host::ForeverAlone)
        expect(File.expand_path(wm.source_location.first))
          .to eq File.expand_path(__FILE__)
        expect(wm.source_location.last).to eq Host::FOREVER_ALONE_LINE
      end

      it 'should return nil if no source_location can be found' do
        expect(Pry::WrappedModule(Host::PitifullyBlank).source_location).to eq nil
      end
    end

    describe "source" do
      it 'should return primary candidates source by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        expect(wm.source).to eq wm.candidate(0).source
      end

      it 'should return source for highest ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(0).source)
          .to match(/test1/)
      end

      it 'should return source for second ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(1).source)
          .to match(/test4/)
      end

      it 'should return source for third ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(2).source)
          .to match(/test6/)
      end

      it 'should return source for deeply nested class' do
        expect(Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested).source)
          .to match(/nested_method/)
        mod = Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested)
        expect(mod.source.lines.count).to eq(3)
      end
    end

    describe "doc" do
      it 'should return primary candidates doc by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        expect(wm.doc).to eq wm.candidate(0).doc
      end

      it 'should return doc for highest ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(0).doc)
          .to match(/rank 0/)
      end

      it 'should return doc for second ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(1).doc)
          .to match(/rank 1/)
      end

      it 'should return doc for third ranked candidate' do
        expect(Pry::WrappedModule(Host::CandidateTest).candidate(2).doc)
          .to match(/rank 2/)
      end

      it 'should return docs for deeply nested class' do
        expect(Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested).doc)
          .to match(/nested docs/)
      end
    end
  end

  describe ".method_prefix" do
    before do
      Foo = Class.new
      @foo = Foo.new
    end

    after do
      Object.remove_const(:Foo)
    end

    it "should return Foo# for normal classes" do
      expect(Pry::WrappedModule.new(Foo).method_prefix).to eq "Foo#"
    end

    it "should return Bar# for modules" do
      expect(Pry::WrappedModule.new(Kernel).method_prefix).to eq "Kernel#"
    end

    it "should return Foo. for singleton classes of classes" do
      expect(Pry::WrappedModule.new(class << Foo; self; end).method_prefix).to eq "Foo."
    end

    example "of singleton classes of objects" do
      expect(Pry::WrappedModule.new(class << @foo; self; end).method_prefix).to eq "self."
    end

    example "of anonymous classes should not be empty" do
      expect(Pry::WrappedModule.new(Class.new).method_prefix).to match(/#<Class:.*>#/)
    end

    example "of singleton classes of anonymous classes should not be empty" do
      expect(Pry::WrappedModule.new(class << Class.new; self; end).method_prefix)
        .to match(/#<Class:.*>./)
    end
  end

  describe ".singleton_class?" do
    it "should be true for singleton classes" do
      mod = Pry::WrappedModule.new(class << Object.new; self; end)
      expect(mod).to be_singleton_class
    end

    it "should be false for normal classes" do
      expect(Pry::WrappedModule.new(Class.new).singleton_class?).to eq false
    end

    it "should be false for modules" do
      expect(Pry::WrappedModule.new(Module.new).singleton_class?).to eq false
    end
  end

  describe ".singleton_instance" do
    it "should raise an exception when called on a non-singleton-class" do
      expect { Pry::WrappedModule.new(Class).singleton_instance }
        .to raise_error ArgumentError
    end

    it "should return the attached object" do
      instance = Object.new
      mod = class << instance; self; end
      expect(Pry::WrappedModule.new(mod).singleton_instance).to eq(instance)

      klass = class << Object; self; end
      expect(Pry::WrappedModule.new(klass).singleton_instance).to equal(Object)
    end
  end

  describe ".super" do
    describe "receiver is a class" do
      before do
        @a = Class.new
        @m = Module.new
        @b = Class.new(@a)
        @b.send(:include, @m)
        @c = Class.new(@b)
      end

      it 'should return superclass for a wrapped class' do
        expect(Pry::WrappedModule(@c).super.wrapped).to eq @b
      end

      it 'should return nth superclass for a wrapped class' do
        d = Class.new(@c)
        expect(Pry::WrappedModule(d).super(2).wrapped).to eq @b
      end

      it 'should ignore modules when retrieving nth superclass' do
        expect(Pry::WrappedModule(@c).super(2).wrapped).to eq @a
      end

      it 'should return nil when no nth superclass exists' do
        expect(Pry::WrappedModule(@c).super(10)).to eq nil
      end

      it 'should return self when .super(0) is used' do
        c = Pry::WrappedModule(@c)
        expect(c.super(0)).to eq c
      end
    end

    describe "receiver is a module" do
      before do
        @m1 = Module.new
        @m2 = Module.new.tap { |v| v.send(:include, @m1) }
        @m3 = Module.new.tap { |v| v.send(:include, @m2) }
      end

      it 'should not ignore modules when retrieving supers' do
        expect(Pry::WrappedModule(@m3).super.wrapped).to eq @m2
      end

      it 'should retrieve nth super' do
        expect(Pry::WrappedModule(@m3).super(2).wrapped).to eq @m1
      end

      it 'should return self when .super(0) is used' do
        m = Pry::WrappedModule(@m1)
        expect(m.super(0)).to eq m
      end
    end
  end

  describe ".from_str" do
    before do
      class Namespace
        remove_const :Value if defined? Value
        Value = Class.new
      end
    end

    it 'should lookup a constant' do
      m = Pry::WrappedModule.from_str("Namespace::Value", binding)
      expect(m.wrapped).to eq Namespace::Value
    end

    it 'should lookup a local' do
      local = Namespace::Value
      m = Pry::WrappedModule.from_str("local", binding)
      expect(m.wrapped).to eq local
    end

    it 'should lookup an ivar' do
      @ivar = Namespace::Value
      m = Pry::WrappedModule.from_str("@ivar", binding)
      expect(m.wrapped).to eq Namespace::Value
    end
  end
end
