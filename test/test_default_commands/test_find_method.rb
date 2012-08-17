require 'helper'

# we turn off the test for MRI 1.8 because our source_location hack
# for C methods actually runs the methods - and since it runs ALL
# methods (in an attempt to find a match) it runs 'exit' and aborts
# the test, causing a failure. We should fix this in the future by
# blacklisting certain methods for 1.8 MRI (such as exit, fork, and so on)
unless Pry::Helpers::BaseHelpers.mri_18?
  MyKlass = Class.new do
    def hello
      "timothy"
    end
    def goodbye
      "jenny"
    end
    def tea_tim?
      "timothy"
    end
    def tea_time?
      "polly"
    end
  end

  describe "find-method" do
    describe "find matching methods by name regex (-n option)" do
      it "should find a method by regex" do
        pry_eval("find-method hell MyKlass").should =~
          /MyKlass.*?hello/m
      end

      it "should NOT match a method that does not match the regex" do
        pry_eval("find-method hell MyKlass").should.not =~
          /MyKlass.*?goodbye/m
      end
    end

    describe "find matching methods by content regex (-c option)" do
      it "should find a method by regex" do
        pry_eval("find-method -c timothy MyKlass").should =~
          /MyKlass.*?hello/m
      end

      it "should NOT match a method that does not match the regex" do
        pry_eval("find-method timothy MyKlass").should.not =~
          /MyKlass.*?goodbye/m
      end
    end

    it "should work with badly behaved constants" do
      MyKlass::X = Object.new
      def (MyKlass::X).hash
        raise "mooo"
      end

      pry_eval("find-method -c timothy MyKlass").should =~
        /MyKlass.*?hello/m
    end

    it "should escape regexes correctly" do
      good = /tea_time\?/
      bad  = /tea_tim\?/
      pry_eval('find-method tea_time? MyKlass').should =~ good
      pry_eval('find-method tea_time? MyKlass').should =~ good
      pry_eval('find-method tea_time\? MyKlass').should.not =~ bad
      pry_eval('find-method tea_time\? MyKlass').should =~ good
    end
  end

  Object.remove_const(:MyKlass)
end
