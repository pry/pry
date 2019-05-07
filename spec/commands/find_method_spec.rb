# frozen_string_literal: true

describe "find-method" do
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

  describe "find matching methods by name regex (-n option)" do
    it "should find a method by regex" do
      expect(pry_eval(binding, "find-method hell MyKlass")).to match(
        /MyKlass.*?hello/m
      )
    end

    it "should NOT match a method that does not match the regex" do
      expect(pry_eval(binding, "find-method hell MyKlass")).not_to match(
        /MyKlass.*?goodbye/m
      )
    end
  end

  describe "find matching methods by content regex (-c option)" do
    it "should find a method by regex" do
      expect(pry_eval(binding, "find-method -c timothy MyKlass")).to match(
        /MyKlass.*?hello/m
      )
    end

    it "should NOT match a method that does not match the regex" do
      expect(pry_eval(binding, "find-method timothy MyKlass")).not_to match(
        /MyKlass.*?goodbye/m
      )
    end
  end

  it "should work with badly behaved constants" do
    MyKlass::X = Object.new
    def (MyKlass::X).hash
      raise "mooo"
    end

    expect(pry_eval(binding, "find-method -c timothy MyKlass")).to match(
      /MyKlass.*?hello/m
    )
  end

  it "should escape regexes correctly" do
    good = /tea_time\?/
    bad  = /tea_tim\?/
    expect(pry_eval(binding, 'find-method tea_time? MyKlass')).to match(good)
    expect(pry_eval(binding, 'find-method tea_time? MyKlass')).to match(good)
    expect(pry_eval(binding, 'find-method tea_time\? MyKlass')).not_to match(bad)
    expect(pry_eval(binding, 'find-method tea_time\? MyKlass')).to match(good)
  end
end
