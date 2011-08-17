require 'helper'

describe "Pry::CommandProcessor" do
  before do
    @pry = Pry.new
    @pry.commands = Pry::CommandSet.new
    @command_processor = Pry::CommandProcessor.new(@pry)
  end

  after do
    @pry.commands = Pry::CommandSet.new
  end

  it 'should accurately determine if a command is valid' do
    @pry.commands.command("test-command") {}
    valid = @command_processor.valid_command? "test-command"
    valid.should == true

    valid = @command_processor.valid_command? "blah"
    valid.should == false
  end

  it 'should correctly match a simple string command' do
    @pry.commands.command("test-command") {}
    command, captures, pos = @command_processor.command_matched "test-command", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should correctly match a simple string command with parameters' do
    @pry.commands.command("test-command") { |arg|}
    command, captures, pos = @command_processor.command_matched "test-command hello", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should not match when the relevant command does not exist' do
    command, captures, pos = @command_processor.command_matched "test-command", binding

    command.should == nil
    captures.should == nil
  end

  it 'should correctly match a regex command' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue hello", binding

    command.name.should == /rue(.?)/
    captures.should == [""]
    pos.should == 3
  end

  it 'should correctly match a regex command and extract the capture groups' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue5 hello", binding

    command.name.should == /rue(.?)/
    captures.should == ["5"]
    pos.should == 4
  end

  it 'should correctly match a string command with spaces in its name' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command", binding

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a string command with spaces in its name with parameters' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command param1 param2", binding

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a command preceded by the command_prefix if one is defined' do
    Pry.config.command_prefix = "%"

    @pry.commands.command("test-command") {}
    command, captures, pos = @command_processor.command_matched "%test-command hello", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length + "%".length

    Pry.config.command_prefix = ''
  end

  it 'should not match a command not preceded by the command_prefix if one is defined' do
    Pry.config.command_prefix = "%"

    @pry.commands.command("test-command") {}
    command, captures, pos = @command_processor.command_matched "test-command hello", binding

    command.should == nil
    captures.should == nil

    Pry.config.command_prefix = ''
  end

  it 'should match a command preceded by the command_prefix when :use_prefix => false' do
    Pry.config.command_prefix = "%"

    @pry.commands.command("test-command", "", :use_prefix => false) {}
    command, captures, pos = @command_processor.command_matched "%test-command hello", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length + "%".length

    Pry.config.command_prefix = ''
  end

  it 'should match a command not preceded by the command_prefix when :use_prefix => false' do
    Pry.config.command_prefix = "%"

    @pry.commands.command("test-command", "", :use_prefix => false) {}
    command, captures, pos = @command_processor.command_matched "test-command hello", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length

    Pry.config.command_prefix = ''
  end

  it 'should correctly match a regex command with spaces in its name' do
    regex_command_name = /test\s+(.+)\s+command/
    @pry.commands.command(regex_command_name) {}

    sample_text = "test friendship command"
    command, captures, pos = @command_processor.command_matched sample_text, binding

    command.name.should == regex_command_name
    captures.should == ["friendship"]
    pos.should == sample_text.size
  end

  it 'should correctly match a complex regex command' do
    regex_command_name = /\.(.*)/
    @pry.commands.command(regex_command_name) {}

    sample_text = ".cd ~/pry"
    command, captures, pos = @command_processor.command_matched sample_text, binding

    command.name.should == regex_command_name
    captures.should == ["cd ~/pry"]
    pos.should == sample_text.size
  end

  it 'should not interpolate commands that have :interpolate => false (interpolate_string should *not* be called)' do
    @pry.commands.command("boast", "", :interpolate => false) {}

    # remember to use '' instead of "" when testing interpolation or
    # you'll cause yourself incredible confusion
    lambda { @command_processor.command_matched('boast #{c}', binding) }.should.not.raise NameError
  end

  it 'should only execute the contents of an interpolation once' do
    $obj = 'a'

    redirect_pry_io(InputTester.new('cat #{$obj.succ!}'), StringIO.new) do
      Pry.new.rep
    end

    $obj.should == 'b'
  end
end
