# frozen_string_literal: true

if $PROGRAM_NAME != __FILE__
  fail "#{__FILE__} should only be executed as a top level program"
end

$LOAD_PATH.unshift File.expand_path(File.join(__dir__, '..', '..', 'lib'))

require 'pry'
require 'pry/testable'

include Pry::Testable::Evalable

class Cor
  def blimey!
    Dir.chdir '..' do
      pry_eval(binding, 'whereami', '_file_')
    end
  end
end

puts Cor.new.blimey!
