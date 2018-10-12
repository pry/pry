require_relative 'helper'
require "readline" unless defined?(Readline)
require "pry/input_completer"

def completer_test(bind, pry=nil, assert_flag=true)
  test = proc {|symbol|
    expect(Pry::InputCompleter.new(pry || Readline, pry).call(symbol[0..-2], target: Pry.binding_for(bind)).include?(symbol)).to eq(assert_flag)}
  return proc {|*symbols| symbols.each(&test) }
end


describe Pry::InputCompleter do
  before do
    # The AMQP gem has some classes like this:
    #  pry(main)> AMQP::Protocol::Test::ContentOk.name
    #  => :content_ok
    module SymbolyName
      def self.name; :symboly_name; end
    end

    @before_completer = Pry.config.completer
    Pry.config.completer = Pry::InputCompleter
  end

  after do
    Pry.config.completer = @before_completer
    Object.remove_const :SymbolyName
  end

  # another jruby hack :((
  if !Pry::Helpers::BaseHelpers.jruby?
    it "should not crash if there's a Module that has a symbolic name." do
      expect { Pry::InputCompleter.new(Readline).call "a.to_s.", target: Pry.binding_for(Object.new) }.not_to raise_error
    end
  end

  it 'should take parenthesis and other characters into account for symbols' do
    expect { Pry::InputCompleter.new(Readline).call ":class)", target: Pry.binding_for(Object.new) }.not_to raise_error
  end

  it 'should complete instance variables' do
    object = Class.new.new

    # set variables in appropriate scope
    object.instance_variable_set(:'@name', 'Pry')
    object.class.send(:class_variable_set, :'@@number', 10)

    # check to see if variables are in scope
    expect(object.instance_variables.
      map { |v| v.to_sym }.
      include?(:'@name')).to eq true

    expect(object.class.class_variables.
      map { |v| v.to_sym }.
      include?(:'@@number')).to eq true

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
      remove_const :Con if defined? Con
      Con = 'Constant'
      module Mod2
      end
    end

    completer_test(Mod).call('Con')

    # Constants or Class Methods
    completer_test(o).call('Mod::Con')

    # Symbol
    _foo = :symbol
    completer_test(o).call(':symbol')

    # Variables
    class << o
      attr_accessor :foo
    end
    o.foo = 'bar'
    completer_test(binding).call('o.foo')

    # trailing slash
    expect(Pry::InputCompleter.new(Readline).call('Mod2/', target: Pry.binding_for(Mod)).include?('Mod2/')).to eq(true)
  end

  it 'should complete for arbitrary scopes' do
    module Bar
      @barvar = :bar
    end

    module Baz
      remove_const :Con if defined? Con
      @bar = Bar
      @bazvar = :baz
      Con = :constant
    end

    pry = Pry.new(target: Baz)
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
      remove_const :Con if defined? Con
      Con = 'Constant'
      module Mod2
      end
    end

    completer_test(Mod).call('Con')

    # Constants or Class Methods
    completer_test(o).call('Mod::Con')

    # Symbol
    _foo = :symbol
    completer_test(o).call(':symbol')

    # Variables
    class << o
      attr_accessor :foo
    end
    o.foo = 'bar'
    completer_test(binding).call('o.foo')

    # trailing slash
    expect(Pry::InputCompleter.new(Readline).call('Mod2/', target: Pry.binding_for(Mod)).include?('Mod2/')).to eq(true)
  end

  it 'should complete for arbitrary scopes' do
    module Bar
      @barvar = :bar
    end

    module Baz
      remove_const :Con if defined? Con
      @bar = Bar
      @bazvar = :baz
      Con = :constant
    end

    pry = Pry.new(target: Baz)
    pry.push_binding(Bar)

    b = Pry.binding_for(Bar)
    completer_test(b, pry).call("../@bazvar")
    completer_test(b, pry).call('/Con')
  end

  it 'should not return nil in its output' do
    pry = Pry.new
    expect(Pry::InputCompleter.new(Readline, pry).call("pry.", target: binding)).not_to include nil
  end

  it 'completes expressions with all available methods' do
    completer_test(self).call("[].size.chars")
  end

  it 'does not offer methods from blacklisted modules' do
    require 'irb'
    completer_test(self, nil, false).call("[].size.parse_printf_format")
  end

  if !Pry::Helpers::BaseHelpers.jruby?
    # Classes that override .hash are still hashable in JRuby, for some reason.
    it 'ignores methods from modules that override Object#hash incompatibly' do
      _m = Module.new do
        def self.hash(a, b)
        end

        def aaaa
        end
      end

      completer_test(self, nil, false).call("[].size.aaaa")
    end
  end
end
