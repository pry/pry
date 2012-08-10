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

  it 'should take parenthesis and other characters into account for symbols' do
    b         = Pry.binding_for(Object.new)
    completer = Pry::InputCompleter.build_completion_proc(b)

    lambda { completer.call(":class)") }.should.not.raise(RegexpError)
  end

  it 'should complete instance variables' do
    object = Object.new

    object.instance_variable_set(:'@name', 'Pry')
    object.class.send(:class_variable_set, :'@@number', 10)

    object.instance_variables.map { |v| v.to_sym } \
      .include?(:'@name').should == true

    object.class.class_variables.map { |v| v.to_sym } \
      .include?(:'@@number').should == true

    completer = Pry::InputCompleter.build_completion_proc(
      Pry.binding_for(object)
    )

    # Complete instance variables.
    completer.call('@na').include?('@name').should                 == true
    completer.call('@name.down').include?('@name.downcase').should == true

    # Complete class variables.
    completer = Pry::InputCompleter.build_completion_proc(
      Pry.binding_for(object.class)
    )

    completer.call('@@nu').include?('@@number').should              == true
    completer.call('@@number.cl').include?('@@number.class').should == true
  end
end

