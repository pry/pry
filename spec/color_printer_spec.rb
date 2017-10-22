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

    describe 'Object subclass' do 
      before do
        class ObjectF < Object 
          def inspect
            'foo'
          end
        end

        class ObjectG < Object
          def inspect 
            raise 
          end
        end
      end

      after do 
        Object.send :remove_const, :ObjectF
        Object.send :remove_const, :ObjectG
      end 

      it 'prints a string' do
        Pry::ColorPrinter.pp(ObjectF.new, io)
        expect(str).to eq('foo')
      end 

      it 'prints a string, even when an exception is raised' do 
        Pry::ColorPrinter.pp(ObjectG.new, io)
        expect(str).to match(/\A#<ObjectG:0x\w+>\z/)
      end
    end

    describe 'BasicObject' do
      it 'prints a string' do
        Pry::ColorPrinter.pp(BasicObject.new, io)
        expect(str).to match(/\A#<BasicObject:0x\w+>\z/)
      end
    end

    describe 'BasicObject subclass' do
      before do
        class BasicF < BasicObject
          def inspect
            'foo'
          end
        end

        class BasicG < BasicObject
          def inspect
            raise
          end
        end
      end

      after do
        Object.__send__ :remove_const, :BasicF
        Object.__send__ :remove_const, :BasicG
      end

      it 'prints a string' do
        Pry::ColorPrinter.pp(BasicF.new, io)
        expect(str).to eq("foo")
      end

      it 'prints a string, even when an exception is raised' do
        Pry::ColorPrinter.pp(BasicG.new, io)
        expect(str).to match(/\A#<BasicG:0x\w+>\z/)
      end
    end

    describe 'String' do
      context 'with a single-line string' do
        it 'pretty prints the string' do
          Pry::ColorPrinter.pp('hello world', io)
          expect(str).to eq('"hello world"')
        end
      end

      context 'with a multi-line string' do
        it 'pretty prints the string' do
          Pry::ColorPrinter.pp("hello\nworld", io)
          expect(str).to eq('"hello\nworld"')
        end
      end
    end
  end
end
