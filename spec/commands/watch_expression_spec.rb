require 'helper'

describe "watch expression" do

  # Custom eval that will:
  # 1) Create an instance of pry that can use for multiple calls
  # 2) Exercise the after_eval hook
  # 3) Return the output
  def eval(expr)
    output = @tester.eval expr
    @tester.pry.hooks.exec_hook :after_eval
    output
  end

  before do
    @tester = pry_tester
    @tester.pry.hooks.clear :after_eval
    eval "watch --delete"
  end

  it "registers the before_session hook" do
    eval 'watch 1+1'
    @tester.pry.hooks.hook_exists?(:after_eval, :watch_expression).should == true
  end

  it "prints no watched expressions" do
    eval('watch').should =~ /No watched expressions/
  end

  it "watches an expression" do
    eval "watch 1+1"
    eval('watch').should =~ /=> 2/
  end

  it "watches a local variable" do
    eval 'foo = :bar'
    eval 'watch foo'
    eval('watch').should =~ /=> :bar/
  end

  #it "prints only when an expression changes" do
  #  # TODO: This is one of the main features, but I am not sure how to test the
  #  # output from a hook.
  #end

  describe "deleting expressions" do
    before do
      eval 'watch :keeper'
      eval 'watch :delete'
      eval 'watch -d 2'
    end

    it "keeps keeper" do
      eval('watch').should =~ /keeper/
    end

    it "deletes delete" do
      eval('watch').should.not =~ /delete/
    end
  end
end
