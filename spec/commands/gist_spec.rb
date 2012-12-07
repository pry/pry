require 'helper'

describe 'gist' do

  # In absence of normal mocking, just monkeysmash these with no undoing after.
  module Jist
    class << self
      def login!; $jist_logged_in = true end
      def gist(*args)
        $jist_gisted = args
        {'html_url' => 'http://gist.blahblah'}
      end
    end
  end

  it 'nominally logs in' do
    pry_eval 'gist --login'
    $jist_logged_in.should.not.be.nil
  end

  module Pry::Helpers::Clipboard
    def self.copy(content); $clipped_content = content end
  end

  EXAMPLE_REPL_METHOD = <<-EOT
  # docdoc
  def my_method
    # line 1
    'line 2'
    line 3
    Line.four
  end
  EOT

  RANDOM_COUPLE_OF_LINES = %w(a=1 b=2)
  run_case = proc do |sym|
    actual_command = Pry::Gist.example_code(sym)
    pry_eval EXAMPLE_REPL_METHOD, RANDOM_COUPLE_OF_LINES, actual_command
  end

  it 'deduces filenames' do
    Pry::Gist::INVOCATIONS.keys.each do |e|
      run_case.call(e)
      if $jist_gisted
        text, args = $jist_gisted
        args[:filename].should.not == '(pry)'
      end
      $clipped_content.should.not.be.nil
      $clipped_content = $jist_gisted = nil
    end
  end

  it 'equates aliae' do
    run_case.call(:clipit).should == run_case.call(:cliponly)
    run_case.call(:jist).should   == run_case.call(:class)
  end

  it 'has a reasonable --help' do
    help = pry_eval('gist --help')
    Pry::Gist::INVOCATIONS.keys.each do |e|
      help.should.include? Pry::Gist.example_code(e)
      help.should.include? Pry::Gist.example_description(e)
    end
  end
end
