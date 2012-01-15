require 'helper'

describe Pry::Code do
  describe '.from_file' do
    it 'should read lines from a file on disk' do
      Pry::Code.from_file('lib/pry.rb').length.should > 0
    end

    it 'should read lines from Pry\'s line buffer' do
      mock_pry(':hay_guys')
      Pry::Code.from_file('(pry)').grep(/:hay_guys/).length.should == 1
    end

    it 'should default to Ruby' do
      temp_file('') do |f|
        Pry::Code.from_file(f.path).code_type.should == :ruby
      end
    end

    it 'should check the extension' do
      temp_file('.c') do |f|
        Pry::Code.from_file(f.path).code_type.should == :c
      end
    end

    it 'should raise an error if the file doesn\'t exist' do
      proc do
        Pry::Code.from_file('/knalkjsdnalsd/alkjdlkq')
      end.should.raise(Pry::CommandError)
    end
  end

  describe '.from_method' do
    it 'should read lines from a method\'s definition' do
      m = Pry::Method.from_obj(Pry, :load_history)
      Pry::Code.from_method(m).length.should > 0
    end
  end

  describe '#initialize' do
    before do
      @str = Pry::Helpers::CommandHelpers.unindent <<-CODE
        def hay
          :guys
        end
      CODE

      @array = ['def hay', '  :guys', 'end']
    end

    it 'should break a string into lines' do
      Pry::Code.new(@str).length.should == 3
    end

    it 'should accept an array' do
      Pry::Code.new(@array).length.should == 3
    end

    it 'an array or string should produce an equivalent object' do
      Pry::Code.new(@str).should == Pry::Code.new(@array)
    end
  end

  describe 'filters and formatters' do
    before do
      @code = Pry::Code(Pry::Helpers::CommandHelpers.unindent <<-STR)
        class MyProgram
          def self.main
            puts 'Hello, world!'
          end
        end
      STR
    end

    describe 'filters' do
      describe '#between' do
        it 'should work with an inclusive range' do
          @code = @code.between(1..3)
          @code.length.should == 3
          @code.should =~ /\Aclass MyProgram/
          @code.should =~ /world!'\Z/
        end

        it 'should default to an inclusive range' do
          @code = @code.between(3, 5)
          @code.length.should == 3
        end

        it 'should work with an exclusive range' do
          @code = @code.between(2...4)
          @code.length.should == 2
          @code.should =~ /\A  def self/
          @code.should =~ /world!'\Z/
        end
      end

      describe '#before' do
        it 'should work' do
          @code = @code.before(3, 1)
          @code.should =~ /\A  def self\.main\Z/
        end
      end

      describe '#around' do
        it 'should work' do
          @code = @code.around(3, 1)
          @code.length.should == 3
          @code.should =~ /\A  def self/
          @code.should =~ /  end\Z/
        end
      end

      describe '#after' do
        it 'should work' do
          @code = @code.after(3, 1)
          @code.should =~ /\A  end\Z/
        end
      end

      describe '#grep' do
        it 'should work' do
          @code = @code.grep(/end/)
          @code.length.should == 2
        end
      end
    end

    describe 'formatters' do
      describe '#with_line_numbers' do
        it 'should show line numbers' do
          @code = @code.with_line_numbers
          @code.should =~ /1:/
        end

        it 'should disable line numbers when falsy' do
          @code = @code.with_line_numbers
          @code = @code.with_line_numbers(false)
          @code.should.not =~ /1:/
        end
      end

      describe '#with_marker' do
        it 'should show a marker in the right place' do
          @code = @code.with_marker(2)
          @code.should =~ /^ =>   def self/
        end

        it 'should disable the marker when falsy' do
          @code = @code.with_marker(2)
          @code = @code.with_marker(false)
          @code.should =~ /^  def self/
        end
      end

      describe '#with_indentation' do
        it 'should indent the text' do
          @code = @code.with_indentation(2)
          @code.should =~ /^    def self/
        end

        it 'should disable the indentation when falsy' do
          @code = @code.with_indentation(2)
          @code = @code.with_indentation(false)
          @code.should =~ /^  def self/
        end
      end
    end
  end
end
