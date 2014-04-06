require_relative '../helper'

describe "gem-list" do
  it 'should not raise when invoked' do
    proc {
      pry_eval(self, 'gem-list')
    }.should.not.raise
  end

  it 'should work arglessly' do
    list = pry_eval('gem-list')
    list.should =~ /bacon \(/
  end

  it 'should find arg' do
    prylist = pry_eval('gem-list slop')
    prylist.should.not =~ /bacon/
  end

  it 'should return non-results as silence' do
    pry_eval('gem-list aoeuoueouaou').should.empty?
  end
end
