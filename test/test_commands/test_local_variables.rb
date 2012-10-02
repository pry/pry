require 'helper'

describe 'local-variables' do
  it 'should find locals and sort by descending size' do
    mock_pry("a = 'asdf'; b = 'x'\nlocal-variables").should =~ /'asdf'.*'x'/
  end
  it 'should not list pry noise' do
    mock_pry('local-variables').should.not =~ /_(?:dir|file|ex|pry|out|in)_/
  end
end
