require_relative 'helper'

describe Pry::Code do
  describe '.from_file' do
    specify 'read lines from a file on disk' do
      expect(Pry::Code.from_file('lib/pry.rb').length).to be > 0
    end

    specify 'read lines from Pry\'s line buffer' do
      pry_eval ':hay_guys'
      expect(Pry::Code.from_file('(pry)').grep(/:hay_guys/).length).to eq 1
    end

    specify 'default to unknown' do
      temp_file('') do |f|
        expect(Pry::Code.from_file(f.path).code_type).to eq :unknown
      end
    end

    specify 'check the extension' do
      temp_file('.c') do |f|
        expect(Pry::Code.from_file(f.path).code_type).to eq :c
      end
    end

    specify 'raise an error if the file doesn\'t exist' do
      expect do
        Pry::Code.from_file('/knalkjsdnalsd/alkjdlkq')
      end.to raise_error MethodSource::SourceNotFoundError
    end

    specify 'check for files relative to origin pwd' do
      Dir.chdir('spec') do |f|
        expect(Pry::Code.from_file('spec/' + File.basename(__FILE__)).code_type).to eq :ruby
      end
    end

    specify 'check for Ruby files relative to origin pwd with `.rb` omitted' do
      Dir.chdir('spec') do |f|
        expect(Pry::Code.from_file('spec/' + File.basename(__FILE__, '.*')).code_type).to eq :ruby
      end
    end

    specify 'find files that are relative to the current working directory' do
      Dir.chdir('spec') do |f|
        expect(Pry::Code.from_file(File.basename(__FILE__)).code_type).to eq :ruby
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
        expect(Pry::Code.from_file('slinky.rb').code_type).to eq :ruby
      end

      it 'finds files with `.rb` omitted' do
        expect(Pry::Code.from_file('slinky').code_type).to eq :ruby
      end

      it 'finds files in a relative directory with `.rb` extension' do
        expect(Pry::Code.from_file('../helper.rb').code_type).to eq :ruby
      end

      it 'finds files in a relative directory with `.rb` omitted' do
        expect(Pry::Code.from_file('../helper').code_type).to eq :ruby
      end

      it "doesn't confuse files with the same name, but without an extension" do
        expect(Pry::Code.from_file('cat_load_path').code_type).to eq :unknown
      end

      it "doesn't confuse files with the same name, but with an extension" do
        expect(Pry::Code.from_file('cat_load_path.rb').code_type).to eq :ruby
      end

      it "recognizes special Ruby files without extensions" do
        expect(Pry::Code.from_file('Gemfile').code_type).to eq :ruby
      end
    end
  end

  describe '.from_method' do
    specify 'read lines from a method\'s definition' do
      m = Pry::Method.from_obj(Pry, :load_history)
      expect(Pry::Code.from_method(m).length).to be > 0
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
      expect(Pry::Code.new(@str).length).to eq 3
    end

    specify 'accept an array' do
      expect(Pry::Code.new(@array).length).to eq 3
    end

    it 'an array or string specify produce an equivalent object' do
      expect(Pry::Code.new(@str)).to eq Pry::Code.new(@array)
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
          expect(@code.length).to eq 3
          expect(@code).to match(/\Aclass MyProgram/)
          expect(@code).to match(/world!'\Z/)
        end

        specify 'default to an inclusive range' do
          @code = @code.between(3, 5)
          expect(@code.length).to eq 3
        end

        specify 'work with an exclusive range' do
          @code = @code.between(2...4)
          expect(@code.length).to eq 2
          expect(@code).to match(/\A  def self/)
          expect(@code).to match(/world!'\Z/)
        end

        specify 'use real line numbers for positive indices' do
          @code = @code.after(3, 3)
          @code = @code.between(4, 4)
          expect(@code.length).to eq 1
          expect(@code).to match(/\A  end\Z/)
        end
      end

      describe '#before' do
        specify 'work' do
          @code = @code.before(3, 1)
          expect(@code).to match(/\A  def self\.main\Z/)
        end
      end

      describe '#around' do
        specify 'work' do
          @code = @code.around(3, 1)
          expect(@code.length).to eq 3
          expect(@code).to match(/\A  def self/)
          expect(@code).to match(/  end\Z/)
        end
      end

      describe '#after' do
        specify 'work' do
          @code = @code.after(3, 1)
          expect(@code).to match(/\A  end\Z/)
        end
      end

      describe '#grep' do
        specify 'work' do
          @code = @code.grep(/end/)
          expect(@code.length).to eq 2
        end
      end
    end

    describe 'formatters' do
      describe '#with_line_numbers' do
        specify 'show line numbers' do
          @code = @code.with_line_numbers
          expect(@code).to match(/1:/)
        end

        specify 'pad multiline units created with edit command' do
          multiline_unit = "def am_i_pretty?\n  'yes i am'\n  end"
          code = Pry::Code.new(multiline_unit).with_line_numbers
          middle_line  = code.split("\n")[1]
          expect(middle_line).to match(/2:   'yes i am'/)
        end

        specify 'disable line numbers when falsy' do
          @code = @code.with_line_numbers
          @code = @code.with_line_numbers(false)
          expect(@code).not_to match(/1:/)
        end
      end

      describe '#with_marker' do
        specify 'show a marker in the right place' do
          @code = @code.with_marker(2)
          expect(@code).to match(/^ =>   def self/)
        end

        specify 'disable the marker when falsy' do
          @code = @code.with_marker(2)
          @code = @code.with_marker(false)
          expect(@code).to match(/^  def self/)
        end
      end

      describe '#with_indentation' do
        specify 'indent the text' do
          @code = @code.with_indentation(2)
          expect(@code).to match(/^    def self/)
        end

        specify 'disable the indentation when falsy' do
          @code = @code.with_indentation(2)
          @code = @code.with_indentation(false)
          expect(@code).to match(/^  def self/)
        end
      end
    end

    describe 'composition' do
      describe 'grep and with_line_numbers' do
        specify 'work' do
          @code = @code.grep(/end/).with_line_numbers
          expect(@code).to match(/\A4:   end/)
          expect(@code).to match(/5: end\Z/)
        end
      end

      describe 'grep and before and with_line_numbers' do
        specify 'work' do
          @code = @code.grep(/e/).before(5, 5).with_line_numbers
          expect(@code).to match(/\A2:   def self.main\n3:/)
          expect(@code).to match(/4:   end\Z/)
        end
      end

      describe 'before and after' do
        specify 'work' do
          @code = @code.before(4, 2).after(2)
          expect(@code).to eq "    puts 'Hello, world!'"
        end
      end
    end
  end
end
