require 'helper'

describe "The whole thing" do
  before do
    Pry.config.auto_indent = true
  end

  after do
    Pry.config.auto_indent = false
  end

  it "should let you run commands in the middle of multiline expressions" do
    ReplTester.start do
      input  'def a'
      input  '!'
      output /^Input buffer cleared/

      input  '5'
      output '=> 5'
    end
  end

  describe "eval_string and binding_stack" do
    it "shouldn't break if we start a nested REPL" do
      ReplTester.start do
        input  'Pry::REPL.new(_pry_, :target => 10).start'
        output ''
        prompt /10.*> $/

        input  'self'
        output '=> 10'

        input  nil # Ctrl-D
        output ''

        input  'self'
        output '=> main'
      end
    end

    it "shouldn't break if we start a nested instance" do
      ReplTester.start do
        input  'Pry.start(10)'
        output ''
        prompt /10.*> $/

        input  'self'
        output '=> 10'

        input  nil # Ctrl-D
        output '=> nil' # return value of Pry session

        input  'self'
        output '=> main'
      end
    end

    it "shouldn't break if we pop bindings in Ruby" do
      ReplTester.start do
        input  'cd 10'
        output ''
        prompt /10.*> $/

        input  '_pry_.binding_stack.pop'
        output /^=> #<Binding/
        prompt /main.*> $/

        input  '_pry_.binding_stack.pop'
        output /^=> #<Binding/
        assert_exited
      end
    end

    it "should immediately evaluate eval_string after cmd if complete" do
      set = Pry::CommandSet.new do
        import Pry::Commands

        command 'hello!' do
          eval_string.replace('"hello"')
        end
      end

      ReplTester.start(:commands => set) do
        input  'def x'
        output ''
        prompt /\*   $/

        input  'hello!'
        output '=> "hello"'
        prompt /> $/
      end
    end
  end
end
