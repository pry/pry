require 'helper'

def completer_test(bind, pry=nil, assert_flag=true)
  test = proc {|symbol|
    Pry::InputCompleter.call(symbol[0..-2], :target => Pry.binding_for(bind), :pry => pry).include?(symbol).should  == assert_flag}
  return proc {|*symbols| symbols.each(&test) }
end

if defined?(Bond) && Readline::VERSION !~ /editline/i
  describe 'bond-based completion' do
    it 'should pull in Bond by default' do
      Pry.config.completer.should == Pry::BondCompleter
    end
  end
end

describe Pry::InputCompleter do

  before do
    # The AMQP gem has some classes like this:
    #  pry(main)> AMQP::Protocol::Test::ContentOk.name
    #  => :content_ok
    module SymbolyName
      def self.name; :symboly_name; end
    end

    $default_completer = Pry.config.completer
    Pry.config.completer = Pry::InputCompleter
  end

  after do
    Pry.config.completer = $default_completer
    Object.remove_const :SymbolyName
  end

  # another jruby hack :((
  if !Pry::Helpers::BaseHelpers.jruby?
    it "should not crash if there's a Module that has a symbolic name." do
      lambda{ Pry::InputCompleter.call "a.to_s.", :target => Pry.binding_for(Object.new) }.should.not.raise Exception
    end
  end

  it 'should take parenthesis and other characters into account for symbols' do
    lambda { Pry::InputCompleter.call(":class)", :target => Pry.binding_for(Object.new)) }.should.not.raise(RegexpError)
  end

  it 'should complete instance variables' do
    object = Class.new.new

    # set variables in appropriate scope
    object.instance_variable_set(:'@name', 'Pry')
    object.class.send(:class_variable_set, :'@@number', 10)

    # check to see if variables are in scope
    object.instance_variables.
      map { |v| v.to_sym }.
      include?(:'@name').should == true

    object.class.class_variables.
      map { |v| v.to_sym }.
      include?(:'@@number').should == true

    # Complete instance variables.
    b = Pry.binding_for(object)
    completer_test(b).call('@name', '@name.downcase')

    # Complete class variables.
    b = Pry.binding_for(object.class)
    completer_test(b).call('@@number', '@@number.class')

  end


  it 'should complete for stdlib symbols' do

    o = Object.new
    # Regexp
    completer_test(o).call('/foo/.extend')

    # Array
    completer_test(o).call('[1].push')
  
    # Hash
    completer_test(o).call('{"a" => "b"}.keys')
    
    # Proc
    completer_test(o).call('{2}.call')

    # Symbol
    completer_test(o).call(':symbol.to_s')

    # Absolute Constant
    completer_test(o).call('::IndexError')
  end

  it 'should complete for target symbols' do
    o = Object.new

    # Constant
    module Mod
      Con = 'Constant'
      module Mod2
      end
    end

    completer_test(Mod).call('Con')

    # Constants or Class Methods
    completer_test(o).call('Mod::Con')

    # Symbol
    foo = :symbol
    completer_test(o).call(':symbol')

    # Variables
    class << o
      attr_accessor :foo
    end
    o.foo = 'bar'
    completer_test(binding).call('o.foo')

    # trailing slash
    Pry::InputCompleter.call('Mod2/', :target => Pry.binding_for(Mod)).include?('Mod2/').should   == true
  end

  it 'should complete for arbitrary scopes' do
    module Bar
      @barvar = :bar
    end

    module Baz
      @bar = Bar
      @bazvar = :baz
      Con = :constant
    end

    pry = Pry.new(:target => Baz)
    pry.push_binding(Bar)

    b = Pry.binding_for(Bar)
    completer_test(b, pry).call("../@bazvar")
    completer_test(b, pry).call('/Con')
  end

  it 'should complete for stdlib symbols' do

    o = Object.new
    # Regexp
    completer_test(o).call('/foo/.extend')

    # Array
    completer_test(o).call('[1].push')
  
    # Hash
    completer_test(o).call('{"a" => "b"}.keys')
    
    # Proc
    completer_test(o).call('{2}.call')

    # Symbol
    completer_test(o).call(':symbol.to_s')

    # Absolute Constant
    completer_test(o).call('::IndexError')
  end

  it 'should complete for target symbols' do
    o = Object.new

    # Constant
    module Mod
      Con = 'Constant'
      module Mod2
      end
    end

    completer_test(Mod).call('Con')

    # Constants or Class Methods
    completer_test(o).call('Mod::Con')

    # Symbol
    foo = :symbol
    completer_test(o).call(':symbol')

    # Variables
    class << o
      attr_accessor :foo
    end
    o.foo = 'bar'
    completer_test(binding).call('o.foo')

    # trailing slash
    Pry::InputCompleter.call('Mod2/', :target => Pry.binding_for(Mod)).include?('Mod2/').should   == true

  end

  it 'should complete for arbitrary scopes' do
    module Bar
      @barvar = :bar
    end

    module Baz
      @bar = Bar
      @bazvar = :baz
      Con = :constant
    end

    pry = Pry.new(:target => Baz)
    pry.push_binding(Bar)

    b = Pry.binding_for(Bar)
    completer_test(b, pry).call("../@bazvar")
    completer_test(b, pry).call('/Con')
  end

end
