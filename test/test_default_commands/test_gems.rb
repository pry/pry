require 'helper'

describe "Pry::DefaultCommands::Gems" do
  describe "gem-list" do

    # fixing bug for 1.8 compat
    it 'should not raise when invoked' do
      proc {
        pry_tester(self).eval('gem-list')
      }.should.not.raise
    end

    it 'should work arglessly' do
      list = pry_eval('gem-list')
      list.should =~ /pry \(/
      list.should =~ /bacon \(/
    end

    it 'should find arg' do
      prylist = pry_eval('gem-list pry')
      prylist.should =~ /pry \(/
      prylist.should !~ /bacon/
    end

    it 'should return non-results as silence' do
      pry_eval('gem-list aoeuoueouaou').should.empty?
    end
  end
end

