require_relative 'helper'
require 'readline' unless defined?(Readline)
require 'pry/input_completer'

describe Pry::InputCompleter do
  around do |ex|
    begin
      # The AMQP gem has some classes like this:
      #  pry(main)> AMQP::Protocol::Test::ContentOk.name
      #  => :content_ok
      module SymbolyName
        def self.name; :symboly_name; end
      end

      old_completer = Pry.config.completer
      Pry.config.completer = described_class
      ex.run
    ensure
      Pry.config.completer = old_completer
      Object.remove_const :SymbolyName
    end
  end

  def completion_for(str, bind, input = Readline, pry = nil)
    described_class.new(input, pry).call(str, :target => Pry.binding_for(bind))
  end

  def completer_test(bind, pry = nil, assert_flag = true)
    test = proc do |symbol|
      expect(completion_for(symbol[0..-2], bind, pry || Readline, pry)).
        public_send(assert_flag ? :to : :to_not, include(symbol))
    end
    proc { |*symbols| symbols.each(&test) }
  end

  # another jruby hack :((
  if !Pry::Helpers::BaseHelpers.jruby?
    it 'should not crash if there`s a Module that has a symbolic name.' do
      expect { completion_for('a.to_s.', Object.new) }.not_to raise_error
    end
  end

  it 'should take parenthesis and other characters into account for symbols' do
    expect { completion_for(':class)', Object.new) }.not_to raise_error
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
    expect(completion_for('Mod2/', Mod)).to include('Mod2/')
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

    pry = Pry.new(:target => Baz)
    pry.push_binding(Bar)

    b = Pry.binding_for(Bar)
    completer_test(b, pry).call('../@bazvar')
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
    expect(completion_for('Mod2/', Mod)).to include('Mod2/')
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

    pry = Pry.new(:target => Baz)
    pry.push_binding(Bar)

    b = Pry.binding_for(Bar)
    completer_test(b, pry).call('../@bazvar')
    completer_test(b, pry).call('/Con')
  end

  it 'should not return nil in its output' do
    expect(completion_for('pry.', binding, Readline, Pry.new)).not_to include nil
  end

  it 'completes expressions with all all available methods' do
    method_name = :custom_method_for_test
    m = Module.new { attr_reader method_name }
    completer_test(self).call("[].size.#{method_name}")
    completer_test(self, nil, false).call("[].size.#{method_name}_invalid")
    # prevent being gc'ed
    expect(m).to be
  end
end
