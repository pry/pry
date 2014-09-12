require_relative 'helper'

describe Pry::Code do
  describe '.from_file' do
    specify 'read lines from a file on disk' do
      Pry::Code.from_file('lib/pry.rb').length.should > 0
    end

    specify 'read lines from Pry\'s line buffer' do
      pry_eval ':hay_guys'
      Pry::Code.from_file('(pry)').grep(/:hay_guys/).length.should == 1
    end

    specify 'default to unknown' do
      temp_file('') do |f|
        Pry::Code.from_file(f.path).code_type.should == :unknown
      end
    end

    specify 'check the extension' do
      temp_file('.c') do |f|
        Pry::Code.from_file(f.path).code_type.should == :c
      end
    end

    specify 'raise an error if the file doesn\'t exist' do
      expect do
        Pry::Code.from_file('/knalkjsdnalsd/alkjdlkq')
      end.to raise_error MethodSource::SourceNotFoundError
    end

    specify 'check for files relative to origin pwd' do
      Dir.chdir('spec') do |f|
        Pry::Code.from_file('spec/' + File.basename(__FILE__)).code_type.should == :ruby
      end
    end

    specify 'check for Ruby files relative to origin pwd with `.rb` omitted' do
      Dir.chdir('spec') do |f|
        Pry::Code.from_file('spec/' + File.basename(__FILE__, '.*')).code_type.should == :ruby
      end
    end

    specify 'find files that are relative to the current working directory' do
      Dir.chdir('spec') do |f|
        Pry::Code.from_file(File.basename(__FILE__)).code_type.should == :ruby
      end
    end

    describe 'find Ruby files relative to $LOAD_PATH' do
      before do
        $LOAD_PATH << 'spec/fixtures'
      end

      after do
        $LOAD_PATH.delete 'spec/fixtures'
      end

      it 'finds files with `.rb` extension' do
        Pry::Code.from_file('slinky.rb').code_type.should == :ruby
      end

      it 'finds files with `.rb` omitted' do
        Pry::Code.from_file('slinky').code_type.should == :ruby
      end

      it 'finds files in a relative directory with `.rb` extension' do
        Pry::Code.from_file('../helper.rb').code_type.should == :ruby
      end

      it 'finds files in a relative directory with `.rb` omitted' do
        Pry::Code.from_file('../helper').code_type.should == :ruby
      end

      it "doesn't confuse files with the same name, but without an extension" do
        Pry::Code.from_file('cat_load_path').code_type.should == :unknown
      end

      it "doesn't confuse files with the same name, but with an extension" do
        Pry::Code.from_file('cat_load_path.rb').code_type.should == :ruby
      end
    end
  end

  describe '.from_method' do
    specify 'read lines from a method\'s definition' do
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

    specify 'break a string into lines' do
      Pry::Code.new(@str).length.should == 3
    end

    specify 'accept an array' do
      Pry::Code.new(@array).length.should == 3
    end

    it 'an array or string specify produce an equivalent object' do
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
        specify 'work with an inclusive range' do
          @code = @code.between(1..3)
          @code.length.should == 3
          @code.should =~ /\Aclass MyProgram/
          @code.should =~ /world!'\Z/
        end

        specify 'default to an inclusive range' do
          @code = @code.between(3, 5)
          @code.length.should == 3
        end

        specify 'work with an exclusive range' do
          @code = @code.between(2...4)
          @code.length.should == 2
          @code.should =~ /\A  def self/
          @code.should =~ /world!'\Z/
        end

        specify 'use real line numbers for positive indices' do
          @code = @code.after(3, 3)
          @code = @code.between(4, 4)
          @code.length.should == 1
          @code.should =~ /\A  end\Z/
        end
      end

      describe '#before' do
        specify 'work' do
          @code = @code.before(3, 1)
          @code.should =~ /\A  def self\.main\Z/
        end
      end

      describe '#around' do
        specify 'work' do
          @code = @code.around(3, 1)
          @code.length.should == 3
          @code.should =~ /\A  def self/
          @code.should =~ /  end\Z/
        end
      end

      describe '#after' do
        specify 'work' do
          @code = @code.after(3, 1)
          @code.should =~ /\A  end\Z/
        end
      end

      describe '#grep' do
        specify 'work' do
          @code = @code.grep(/end/)
          @code.length.should == 2
        end
      end
    end

    describe 'formatters' do
      describe '#with_line_numbers' do
        specify 'show line numbers' do
          @code = @code.with_line_numbers
          @code.should =~ /1:/
        end

        specify 'disable line numbers when falsy' do
          @code = @code.with_line_numbers
          @code = @code.with_line_numbers(false)
          @code.should_not =~ /1:/
        end
      end

      describe '#with_marker' do
        specify 'show a marker in the right place' do
          @code = @code.with_marker(2)
          @code.should =~ /^ =>   def self/
        end

        specify 'disable the marker when falsy' do
          @code = @code.with_marker(2)
          @code = @code.with_marker(false)
          @code.should =~ /^  def self/
        end
      end

      describe '#with_indentation' do
        specify 'indent the text' do
          @code = @code.with_indentation(2)
          @code.should =~ /^    def self/
        end

        specify 'disable the indentation when falsy' do
          @code = @code.with_indentation(2)
          @code = @code.with_indentation(false)
          @code.should =~ /^  def self/
        end
      end
    end

    describe 'composition' do
      describe 'grep and with_line_numbers' do
        specify 'work' do
          @code = @code.grep(/end/).with_line_numbers
          @code.should =~ /\A4:   end/
          @code.should =~ /5: end\Z/
        end
      end

      describe 'grep and before and with_line_numbers' do
        specify 'work' do
          @code = @code.grep(/e/).before(5, 5).with_line_numbers
          @code.should =~ /\A2:   def self.main\n3:/
          @code.should =~ /4:   end\Z/
        end
      end

      describe 'before and after' do
        specify 'work' do
          @code = @code.before(4, 2).after(2)
          @code.should == "    puts 'Hello, world!'"
        end
      end
    end
  end
end
