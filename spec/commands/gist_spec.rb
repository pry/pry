# These tests are out of date.
# THey need to be updated for the new 'gist' API, but im too sleepy to
# do that now.

require 'helper'

describe 'gist' do
  it 'has a dependency on the jist gem' do
    Pry::Command::Gist.command_options[:requires_gem].should == "jist"
  end
end

#   before do
#     Pad.jist_calls = {}
#   end

#   # In absence of normal mocking, just monkeysmash these with no undoing after.
#   module Jist
#     class << self
#       def login!; Pad.jist_calls[:login!] = true end
#       def gist(*args)
#         Pad.jist_calls[:gist_args] = args
#         {'html_url' => 'http://gist.blahblah'}
#       end
#       def copy(content); Pad.jist_calls[:copy_args] = content end
#     end
#   end

#   module Pry::Gist
#     # a) The actual require fails for jruby for some odd reason.
#     # b) 100% of jist should be stubbed by the above, so this ensures that.
#     def self.require_jist; 'nope' end
#   end

#   it 'nominally logs in' do
#     pry_eval 'gist --login'
#     Pad.jist_calls[:login!].should.not.be.nil
#   end

#   EXAMPLE_REPL_METHOD = <<-EOT
#   # docdoc
#   def my_method
#     # line 1
#     'line 2'
#     line 3
#     Line.four
#   end
#   EOT

#   RANDOM_COUPLE_OF_LINES = %w(a=1 b=2)
#   run_case = proc do |sym|
#     actual_command = Pry::Gist.example_code(sym)
#     pry_eval EXAMPLE_REPL_METHOD, RANDOM_COUPLE_OF_LINES, actual_command
#   end

#   it 'deduces filenames' do
#     Pry::Gist::INVOCATIONS.keys.each do |e|
#       run_case.call(e)
#       if Pad.jist_calls[:gist_args]
#         text, args = Pad.jist_calls[:gist_args]
#         args[:filename].should.not == '(pry)'
#       end
#       Pad.jist_calls[:copy_args].should.not.be.nil
#     end
#   end

#   it 'equates aliae' do
#     run_case.call(:clipit).should == run_case.call(:cliponly)
#     run_case.call(:jist).should   == run_case.call(:class)
#   end

#   it 'has a reasonable --help' do
#     help = pry_eval('gist --help')
#     Pry::Gist::INVOCATIONS.keys.each do |e|
#       help.should.include? Pry::Gist.example_code(e)
#       help.should.include? Pry::Gist.example_description(e)
#     end
#   end
# end
