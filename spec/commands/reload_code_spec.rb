require_relative '../helper'

describe "reload_code" do
  describe "reload_current_file" do
    it 'raises an error source code not found' do
      proc do
        eval <<-RUBY, TOPLEVEL_BINDING, 'does_not_exist.rb', 1
          pry_eval(binding, "reload-code")
        RUBY
      end.should.raise(Pry::CommandError)
    end

    it 'raises an error when class not found' do
      proc do
        pry_eval(
          "cd Class.new(Class.new{ def goo; end; public :goo })",
          "reload-code")
      end.should.raise(Pry::CommandError)
    end

    it 'reloads pry commmand' do
      pry_eval("reload-code reload-code").should =~ /reload-code was reloaded!/
    end

    it 'raises an error when pry command not found' do
      proc do
        pry_eval(
          "reload-code not-a-real-command")
      end.should.raise(Pry::CommandError).message.should =~ /Cannot locate not-a-real-command!/
    end
  end
end
