require_relative '../helper'

describe "watch expression" do

  # Custom eval that will:
  # 1) Create an instance of pry that can use for multiple calls
  # 2) Exercise the after_eval hook
  # 3) Return the output
  def eval(expr)
    output = @tester.eval expr
    @tester.pry.hooks.exec_hook :after_eval, nil, @tester.pry
    output
  end

  before do
    @tester = pry_tester
    @tester.pry.hooks.clear_event_hooks(:after_eval)
    eval "watch --delete"
  end

  it "registers the after_eval hook" do
    eval 'watch 1+1'
    expect(@tester.pry.hooks.hook_exists?(:after_eval, :watch_expression)).to eq(true)
  end

  it "prints no watched expressions" do
    expect(eval('watch')).to match(/No watched expressions/)
  end

  it "watches an expression" do
    eval "watch 1+1"
    expect(eval('watch')).to match(/=> 2/)
  end

  it "watches a local variable" do
    eval 'foo = :bar'
    eval 'watch foo'
    expect(eval('watch')).to match(/=> :bar/)
  end

  it "prints when an expression changes" do
    ReplTester.start do
      input 'a = 1'
      output '=> 1'

      input 'watch a'
      output "Watching a\nwatch: a => 1"

      input "a = 2"
      output "watch: a => 2\n=> 2"
    end
  end

  it "prints when an expression is mutated" do
    ReplTester.start do
      input 'a = "one"'
      output '=> "one"'

      input 'watch a'
      output %(Watching a\nwatch: a => "one")

      input "a.sub! 'o', 'p'"
      output %(watch: a => "pne"\n=> "pne")
    end
  end

  it "doesn't print when an expresison remains the same" do
    ReplTester.start do
      input 'a = 1'
      output '=> 1'

      input 'watch a'
      output "Watching a\nwatch: a => 1"

      input "a = 1"
      output "=> 1"
    end
  end

  it "continues to work if you start a second pry instance" do
    ReplTester.start do
      input 'a = 1'
      output '=> 1'

      input 'watch a'
      output "Watching a\nwatch: a => 1"

      input "a = 2"
      output "watch: a => 2\n=> 2"
    end

    ReplTester.start do
      input 'b = 1'
      output '=> 1'

      input 'watch b'
      output "Watching b\nwatch: b => 1"

      input "b = 2"
      output "watch: b => 2\n=> 2"
    end
  end

  describe "deleting expressions" do
    before do
      eval 'watch :keeper'
      eval 'watch :delete'
      eval 'watch -d 2'
    end

    it "keeps keeper" do
      expect(eval('watch')).to match(/keeper/)
    end

    it "deletes delete" do
      expect(eval('watch')).not_to match(/delete/)
    end
  end
end
