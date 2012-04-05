require 'helper'

describe 'Pry::DefaultCommands::CD' do
  describe 'cd' do
    # Regression test for ticket #516.
    #it 'should be able to cd into the Object BasicObject.' do
    #  mock_pry('cd BasicObject.new').should.not =~ /\Aundefined method `__binding__'/
    #end
    
    # Regression test for ticket #516
    # Possibly move higher up.
    it 'should not fail with undefined BasicObject#is_a?' do
      mock_pry('cd BasicObject.new').should.not =~ /undefined method `is_a\?'/
    end
  end
end
