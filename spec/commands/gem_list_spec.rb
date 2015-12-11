require_relative '../helper'

describe "gem-list" do
  it 'should not raise when invoked' do
    expect { pry_eval(self, 'gem-list') }.to_not raise_error
  end

  it 'should work arglessly' do
    list = pry_eval('gem-list')
    expect(list).to match(/rspec \(/)
  end

  it 'should find arg' do
    prylist = pry_eval('gem-list method_source')
    expect(prylist).to match(/method_source \(/)
    expect(prylist).not_to match(/rspec/)
  end

  it 'should return non-results as silence' do
    expect(pry_eval('gem-list aoeuoueouaou')).to be_empty
  end
end
