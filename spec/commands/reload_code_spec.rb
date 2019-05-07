# frozen_string_literal: true

describe "reload_code" do
  describe "reload_current_file" do
    it 'raises an error source code not found' do
      expect do
        eval <<-RUBY, TOPLEVEL_BINDING, 'does_not_exist.rb', 1
          pry_eval(binding, "reload-code")
        RUBY
      end.to raise_error(Pry::CommandError)
    end

    it 'raises an error when class not found' do
      expect do
        pry_eval(
          "cd Class.new(Class.new{ def goo; end; public :goo })",
          "reload-code"
        )
      end.to raise_error(Pry::CommandError)
    end

    it 'reloads pry commmand' do
      expect(pry_eval("reload-code reload-code")).to match(/reload-code was reloaded!/)
    end

    it 'raises an error when pry command not found' do
      expect do
        pry_eval(
          "reload-code not-a-real-command"
        )
      end.to raise_error(Pry::CommandError, /Cannot locate not-a-real-command!/)
    end
  end
end
