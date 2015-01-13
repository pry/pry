require 'helper'
describe Pry::ColorPrinter do    
  include Pry::Helpers::Text
  let(:io) { StringIO.new }
  let(:str) { strip_color(io.string.chomp) }
  
  describe '.pp' do
    describe 'Object' do
      it 'prints a string' do
        Pry::ColorPrinter.pp(Object.new, io)
        expect(str).to match(/\A#<Object:0x\w+>\z/)
      end
    end

    describe 'BasicObject' do
      it 'prints a string' do
        Pry::ColorPrinter.pp(BasicObject.new, io)
        expect(str).to match(/\A#<BasicObject:0x\w+>\z/)
      end
    end

    describe 'BasicObject subclass' do
      class F < BasicObject
        def inspect
          'foo'
        end
      end

      it 'prints a string' do
        Pry::ColorPrinter.pp(F.new, io)
        expect(str).to eq("foo")
      end
    end
  end
end
