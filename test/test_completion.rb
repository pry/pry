require 'helper'

describe Pry::InputCompleter do

  before do
    # The AMQP gem has some classes like this:
    #  pry(main)> AMQP::Protocol::Test::ContentOk.name
    #  => :content_ok
    module SymbolyName
      def self.name; :symboly_name; end
    end
  end

  after do
    Object.remove_const :SymbolyName
  end

  # another jruby hack :((
  if !Pry::Helpers::BaseHelpers.jruby?
    it "should not crash if there's a Module that has a symbolic name." do
      completer = Pry::InputCompleter.build_completion_proc(Pry.binding_for(Object.new))
      lambda{ completer.call "a.to_s." }.should.not.raise Exception
    end
  end
end

