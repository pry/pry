require 'helper'

describe Pry::WrappedModule do

  describe "#initialize" do
    it "should raise an exception when a non-module is passed" do
      lambda{ Pry::WrappedModule.new(nil) }.should.raise ArgumentError
    end
  end

  describe "candidates" do
    before do
      class Host
        %w(spec/fixtures/candidate_helper1.rb
           spec/fixtures/candidate_helper2.rb).each do |file|
          binding.eval File.read(file), file, 1
        end

        # rank 2
        class CandidateTest
          def test6
          end
        end

        class ForeverAlone
          class DoublyNested
            # nested docs
            class TriplyNested
              def nested_method
              end
            end
          end
        end
      end
    end

    describe "number_of_candidates" do
      it 'should return the correct number of candidates' do
        Pry::WrappedModule(Host::CandidateTest).number_of_candidates.should == 3
      end

      it 'should return 0 candidates for a class with no methods and no other definitions' do
        Pry::WrappedModule(Host::ForeverAlone).number_of_candidates.should == 0
      end
    end

    describe "ordering of candidates" do
      it 'should return class with largest number of methods as primary candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(0).file.should =~ /helper1/
      end

      it 'should return class with second largest number of methods as second ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(1).file.should =~ /helper2/
      end

      it 'should return class with third largest number of methods as third ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(2).file.should =~ /#{__FILE__}/
      end

      it 'should raise when trying to access non-existent candidate' do
        lambda { Pry::WrappedModule(Host::CandidateTest).candidate(3) }.should.raise Pry::CommandError
      end
    end

    describe "source_location" do
      it 'should return primary candidates source_location by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        wm.source_location.should == wm.candidate(0).source_location
      end

      it 'should return nil if no source_location can be found' do
        Pry::WrappedModule(Host::ForeverAlone).source_location.should == nil
      end
    end

    describe "source" do
      it 'should return primary candidates source by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        wm.source.should == wm.candidate(0).source
      end

      it 'should return source for highest ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(0).source.should =~ /test1/
      end

      it 'should return source for second ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(1).source.should =~ /test4/
      end

      it 'should return source for third ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(2).source.should =~ /test6/
      end

      it 'should return source for deeply nested class' do
        Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested).source.should =~ /nested_method/
        Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested).source.lines.count.should == 4
      end
    end

    describe "doc" do
      it 'should return primary candidates doc by default' do
        wm = Pry::WrappedModule(Host::CandidateTest)
        wm.doc.should == wm.candidate(0).doc
      end

      it 'should return doc for highest ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(0).doc.should =~ /rank 0/
      end

      it 'should return doc for second ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(1).doc.should =~ /rank 1/
      end

      it 'should return doc for third ranked candidate' do
        Pry::WrappedModule(Host::CandidateTest).candidate(2).doc.should =~ /rank 2/
      end

      it 'should return docs for deeply nested class' do
        Pry::WrappedModule(Host::ForeverAlone::DoublyNested::TriplyNested).doc.should =~ /nested docs/
      end
    end

    after do
      Object.remove_const(:Host)
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
      Pry::WrappedModule.new(Foo).method_prefix.should == "Foo#"
    end

    it "should return Bar# for modules" do
      Pry::WrappedModule.new(Kernel).method_prefix.should == "Kernel#"
    end

    it "should return Foo. for singleton classes of classes" do
      Pry::WrappedModule.new(class << Foo; self; end).method_prefix.should == "Foo."
    end

    describe "of singleton classes of objects" do
      Pry::WrappedModule.new(class << @foo; self; end).method_prefix.should == "self."
    end

    describe "of anonymous classes should not be empty" do
      Pry::WrappedModule.new(Class.new).method_prefix.should =~ /#<Class:.*>#/
    end

    describe "of singleton classes of anonymous classes should not be empty" do
      Pry::WrappedModule.new(class << Class.new; self; end).method_prefix.should =~ /#<Class:.*>./
    end
  end

  describe ".singleton_class?" do
    it "should be true for singleton classes" do
      Pry::WrappedModule.new(class << ""; self; end).singleton_class?.should == true
    end

    it "should be false for normal classes" do
      Pry::WrappedModule.new(Class.new).singleton_class?.should == false
    end

    it "should be false for modules" do
      Pry::WrappedModule.new(Module.new).singleton_class?.should == false
    end
  end

  describe ".singleton_instance" do
    it "should raise an exception when called on a non-singleton-class" do
      lambda{ Pry::WrappedModule.new(Class).singleton_instance }.should.raise ArgumentError
    end

    it "should return the attached object" do
      Pry::WrappedModule.new(class << "hi"; self; end).singleton_instance.should == "hi"
      Pry::WrappedModule.new(class << Object; self; end).singleton_instance.should.equal?(Object)
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

      it 'should return superclass for a wrapped class'  do
        Pry::WrappedModule(@c).super.wrapped.should == @b
      end

      it 'should return nth superclass for a wrapped class'  do
        d = Class.new(@c)
        Pry::WrappedModule(d).super(2).wrapped.should == @b
      end

      it 'should ignore modules when retrieving nth superclass'  do
        Pry::WrappedModule(@c).super(2).wrapped.should == @a
      end

      it 'should return nil when no nth superclass exists' do
        Pry::WrappedModule(@c).super(10).should == nil
      end

      it 'should return self when .super(0) is used' do
        c = Pry::WrappedModule(@c)
        c.super(0).should == c
      end
    end

    describe "receiver is a module" do
      before do
        @m1 = Module.new
        @m2 = Module.new.tap { |v| v.send(:include, @m1) }
        @m3 = Module.new.tap { |v| v.send(:include, @m2) }
      end

      it 'should not ignore modules when retrieving supers' do
        Pry::WrappedModule(@m3).super.wrapped.should == @m2
      end

      it 'should retrieve nth super' do
        Pry::WrappedModule(@m3).super(2).wrapped.should == @m1
      end

      it 'should return self when .super(0) is used' do
        m = Pry::WrappedModule(@m1)
        m.super(0).should == m
      end
    end
  end

  describe ".from_str" do
    it 'should lookup a constant' do
      m = Pry::WrappedModule.from_str("Host::CandidateTest", binding)
      m.wrapped.should == Host::CandidateTest
    end

    it 'should lookup a local' do
      local = Host::CandidateTest
      m = Pry::WrappedModule.from_str("local", binding)
      m.wrapped.should == Host::CandidateTest
    end

    it 'should lookup an ivar' do
      @ivar = Host::CandidateTest
      m = Pry::WrappedModule.from_str("@ivar", binding)
      m.wrapped.should == Host::CandidateTest
    end
  end
end
