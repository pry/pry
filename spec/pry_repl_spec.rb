require 'helper'

describe "The REPL" do
  before do
    Pry.config.auto_indent = true
  end

  after do
    Pry.config.auto_indent = false
  end

  it "should let you run commands in the middle of multiline expressions" do
    mock_pry("def a", "!", "5").should =~ /Input buffer cleared/
  end

  it "shouldn't break if we start a nested session" do
    ReplTester.start do |t|
      t.in  'Pry::REPL.start(:pry => _pry_, :target => 10)'
      t.out ''
      t.prompt /10.*> $/

      t.in  'self'
      t.out '=> 10'

      t.in  nil
      t.out ''

      t.in  'self'
      t.out '=> main'
    end
  end
end
