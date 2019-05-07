# frozen_string_literal: true

require 'tempfile'

describe "cat" do
  before do
    @str_output = StringIO.new

    @t = pry_tester do
      def insert_nil_input
        @pry.update_input_history(nil)
      end

      def last_exception=(exception)
        @pry.last_exception = exception
      end
    end
  end

  describe "when invoked without arguments" do
    it 'should display an error message' do
      expect { @t.eval 'cat' }
        .to raise_error(Pry::CommandError, /Must provide a filename/)
    end
  end

  describe "on receiving a file that does not exist" do
    it 'should display an error message' do
      expect { @t.eval 'cat supercalifragilicious66' }
        .to raise_error(StandardError, /Cannot open/)
    end
  end

  describe "with --in" do
    it 'should display the last few expressions with indices' do
      expect(@t.eval('10', '20', 'cat --in')).to eq unindent(<<-STR)
        1:
          10
        2:
          20
      STR
    end
  end

  describe "with --in 1" do
    it 'should display the first expression with no index' do
      expect(@t.eval('10', '20', 'cat --in 1')).to eq("10\n")
    end
  end

  describe "with --in -1" do
    it 'should display the last expression with no index' do
      expect(@t.eval('10', '20', 'cat --in -1')).to eq("20\n")
    end
  end

  describe "with --in 1..2" do
    it 'should display the given range with indices, omitting nils' do
      @t.eval '10'
      @t.insert_nil_input # normally happens when a command is executed
      @t.eval ':hello'

      expect(@t.eval('cat --in 1..3')).to eq(unindent(<<-RANGE))
        1:
          10
        3:
          :hello
      RANGE
    end
  end

  describe "with --ex" do
    before do
      @o = Object.new

      # this is to test exception code (cat --ex)
      def @o.broken_method
        this method is broken
      end
    end

    it 'cat --ex should display repl code that generated exception' do
      @t.eval(unindent(<<-LAST_EXCEPTION))
        begin
          this raises error
        rescue => e
          pry_instance.last_exception = e
        end
      LAST_EXCEPTION
      expect(@t.eval('cat --ex')).to match(/\d+:(\s*) this raises error/)
    end

    it 'cat --ex should correctly display code that generated exception' do
      begin
        @o.broken_method
      rescue StandardError => e
        @t.last_exception = e
      end
      expect(@t.eval('cat --ex')).to match(/this method is broken/)
    end
  end

  describe "with --ex N" do
    it 'should cat first level of backtrace when --ex used with no argument ' do
      temp_file do |f|
        f << "bt number 1"
        f.flush
        @t.last_exception = mock_exception("#{f.path}:1", 'x', 'x')
        expect(@t.eval('cat --ex')).to match(/bt number 1/)
      end
    end

    it 'should cat first level of backtrace when --ex 0 used ' do
      temp_file do |f|
        f << "bt number 1"
        f.flush
        @t.last_exception = mock_exception("#{f.path}:1", 'x', 'x')
        expect(@t.eval('cat --ex 0')).to match(/bt number 1/)
      end
    end

    it 'should cat second level of backtrace when --ex 1 used ' do
      temp_file do |f|
        f << "bt number 2"
        f.flush
        @t.last_exception = mock_exception('x', "#{f.path}:1", 'x')
        expect(@t.eval('cat --ex 1')).to match(/bt number 2/)
      end
    end

    it 'should cat third level of backtrace when --ex 2 used' do
      temp_file do |f|
        f << "bt number 3"
        f.flush
        @t.last_exception = mock_exception('x', 'x', "#{f.path}:1")
        expect(@t.eval('cat --ex 2')).to match(/bt number 3/)
      end
    end

    it 'should show error when backtrace level out of bounds' do
      @t.last_exception = mock_exception('x', 'x', 'x')
      expect { @t.eval('cat --ex 3') }
        .to raise_error(Pry::CommandError, /out of bounds/)
    end

    it(
      'each successive cat --ex should show the next level of backtrace, ' \
      'and going past the final level should return to the first'
    ) do
      temp_files = []
      3.times do |i|
        temp_files << Tempfile.new(['pry', '.rb'])
        temp_files.last << "bt number #{i}"
        temp_files.last.flush
      end

      @t.last_exception = mock_exception(*temp_files.map { |f| "#{f.path}:1" })

      3.times do |i|
        expect(@t.eval('cat --ex')).to match(/bt number #{i}/)
      end

      expect(@t.eval('cat --ex')).to match(/bt number 0/)

      temp_files.each do |file|
        file.close(true)
      end
    end
  end
end
