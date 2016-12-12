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
  let(:instance) { described_class.new(Readline) }

  def completion_for(str, bind, input = nil, pry = nil)
    # Use default instance if input & pry are nil
    instance = input || pry ? described_class.new(input || Readline, pry) : self.instance
    instance.call(str, :target => Pry.binding_for(bind))
  end

  def completer_test(bind, pry = nil, assert_flag = true)
    test = proc do |symbol|
      expect(completion_for(symbol[0..-2], bind, nil, pry)).
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

  context 'for expressions' do
    let(:method_1) { :custom_method_for_test }
    let(:method_2) { :custom_method_for_test_other }
    let!(:custom_module) do
      method = method_1
      Module.new { attr_reader method }
    end
    let(:custom_module_2) do
      method = method_2
      Module.new { attr_accessor method }
    end
    # gc to reset method_cache_version in old rubies and jruby
    before { GC.start }

    it 'completes expressions with all all available methods' do
      completer_test(self).call("[].size.#{method_1}")
      completer_test(self, nil, false).call("[].size.#{method_2}")
    end

    it 'uses cached list of methods' do
      expect(instance).to receive(:all_available_methods).and_call_original
      completer_test(self).call("[].size.#{method_1}")
      completer_test(self, nil, false).call("[].size.#{method_2}")
      custom_module_2
      expect(instance).to receive(:all_available_methods).and_call_original
      completer_test(self).call("[].size.#{method_1}")
      completer_test(self).call("[].size.#{method_2}")
    end

    it 'does not offer methods from blacklisted modules' do
      require 'irb'
      completer_test(self, nil, false).call("[].size.parse_printf_format")
    end
  end
end
