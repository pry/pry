require 'helper'

MyKlass = Class.new do
  def hello
    "timothy"
  end
  def goodbye
    "jenny"
  end
end

describe "find-command" do
  describe "find matching methods by name regex (-n option)" do
    it "should find a method by regex" do
      mock_pry("find-method hell MyKlass").should =~ /MyKlass.*?hello/m
    end
 
    it "should NOT match a method that does not match the regex" do
      mock_pry("find-method hell MyKlass").should.not =~ /MyKlass.*?goodbye/m
    end
  end

  describe "find matching methods by content regex (-c option)" do
    it "should find a method by regex" do
      mock_pry("find-method -c timothy MyKlass").should =~ /MyKlass.*?hello/m
    end

    it "should NOT match a method that does not match the regex" do
      mock_pry("find-method timothy MyKlass").should.not =~ /MyKlass.*?goodbye/m
    end
  end
  
end

Object.remove_const(:MyKlass)
