require 'helper'

describe "Pry#input_stack" do
  it 'should accept :input_stack as a config option' do
    stack = [StringIO.new("test")]
    Pry.new(:input_stack => stack).input_stack.should == stack
  end

  it 'should use defaults from Pry.config' do
    Pry.config.input_stack = [StringIO.new("exit")]
    Pry.new.input_stack.should == Pry.config.input_stack
    Pry.config.input_stack = []
  end

  it 'should read from all input objects on stack and exit session' do
    stack = [b = StringIO.new(":cloister\nexit\n"), c = StringIO.new(":baron\n")]
    instance = Pry.new(:input => StringIO.new(":alex\n"),
                       :output => str_output = StringIO.new,
                       :input_stack => stack)

    instance.repl
    str_output.string.should =~ /:alex/
    str_output.string.should =~ /:baron/
    str_output.string.should =~ /:cloister/
  end

end
