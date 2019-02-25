# These tests are out of date.
# They need to be updated for the new 'gist' API, but im too sleepy to
# do that now.
describe 'gist' do
  it 'has a dependency on the jist gem' do
    expect(Pry::Command::Gist.command_options[:requires_gem]).to eq("gist")
  end

  before do
    Pad.gist_calls = {}
  end

  # In absence of normal mocking, just monkeysmash these with no undoing after.
  module ::Gist
    class << self
      def login!; Pad.gist_calls[:login!] = true end

      def gist(*args)
        Pad.gist_calls[:gist_args] = args
        { 'html_url' => 'http://gist.blahblah' }
      end

      def copy(content); Pad.gist_calls[:copy_args] = content end
    end
  end

  it 'nominally logs in' do
    pry_eval 'gist --login'
    expect(Pad.gist_calls[:login!]).not_to be_nil
  end
end
