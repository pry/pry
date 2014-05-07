require_relative '../helper'

describe "reload_code" do

  before do
    @some_class = Class.new
    @command_error = Pry::CommandError
  end

  describe "reload_current_file" do
    it 'raises an error source code not found' do
      proc do
        pry_eval(
          "reload-code")
      end.should.raise(@command_error).message.should =~ /cannot be found on disk!/
    end

    it 'raises an error when class not found' do
      proc do
        pry_eval(
          "cd Class.new(Class.new{ def goo; end; public :goo })",
          "reload-code")
      end.should.raise(@command_error).message.should =~ /Cannot locate self/
    end
  end

  describe "reload_object" do
    context = {
      :target => binding,
      :output => StringIO.new,
      :pry_instance => Object.new,
      :reload_code => Pry::Command::ReloadCode.new,
      :code_object => Pry::CodeObject,
      :some_class => Class.new
    }

    before do
      context[:reload_code].stubs(:args).returns([])
      context[:reload_code].stubs(:check_for_reloadability).returns(true)
      context[:target].stubs(:eval).returns(Class)
      context[:reload_code].stubs(:target).returns(context[:target])
      context[:reload_code].stubs(:load)
      context[:reload_code].stubs(:output).returns(context[:pry_instance])
    end

    it 'loads code_object and outputs success message' do
      context[:code_object].expects(:lookup).returns(@some_class)
      @some_class.expects(:source_file)
      context[:pry_instance].expects(:puts).with("self was reloaded!")
      context[:reload_code].process
    end
  end
end
