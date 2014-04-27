require_relative '../helper'

describe "reload_code" do
  describe "reload_current_file" do
    it 'raises an error source code not found' do
      proc do
        pry_eval(
          "reload-code")
      end.should.raise(Pry::CommandError).message.should =~ /cannot be found on disk!/
    end

    it 'raises an error when class not found' do
      proc do
        pry_eval(
          "cd Class.new(Class.new{ def goo; end; public :goo })",
          "reload-code")
      end.should.raise(Pry::CommandError).message.should =~ /Cannot locate self/
    end
  end
end
