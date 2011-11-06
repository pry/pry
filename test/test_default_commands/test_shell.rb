require 'helper'

describe "Pry::DefaultCommands::Shell" do
  describe "cat" do

    describe "on receiving a file that does not exist" do
      it 'should display an error message' do
        mock_pry("cat supercalifragilicious66").should =~ /Could not find file/
      end
    end

    describe "with --in" do
      it 'should display the last few expressions with indices' do
        output = mock_pry("10", "20", "cat --in")
        output.should =~ /^1:/
        output.should =~ /^  10/
        output.should =~ /^2:/
        output.should =~ /^  20/
      end
    end

    describe "with --in 1" do
      it 'should display the first expression with no index' do
        output = mock_pry("10", "20", "cat --in 1")
        output.should.not =~ /^\d+:/
        output.should =~ /^10/
      end
    end

    describe "with --in -1" do
      it 'should display the last expression with no index' do
        output = mock_pry("10", "20", "cat --in -1")
        output.should.not =~ /^\d+:/
        output.should =~ /^20/
      end
    end

    describe "with --in 1..2" do
      it 'should display the given range with indices, omitting nils' do
        output = mock_pry("10", "20", "cat --ex", ":hello", "cat --in 1..4")
        output.should =~ /^1:/
        output.should.not =~ /^3:/
        output.should =~ /^  :hello/
      end
    end

    # this doesnt work so well on rbx due to differences in backtrace
    # so we currently skip rbx until we figure out a workaround
    describe "with --ex" do
      if !rbx?
        it 'cat --ex should correctly display code that generated exception even if raised in repl' do
          mock_pry("this raises error", "cat --ex").should =~ /\d+:(\s*) this raises error/
        end

        it 'cat --ex should correctly display code that generated exception' do
          mock_pry("broken_method", "cat --ex").should =~ /this method is broken/
        end
      end
    end

    describe "with --ex N" do
      it 'should cat first level of backtrace when --ex used with no argument ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 1"
          f.flush
          pry_instance.last_exception = MockPryException.new("#{f.path}:1", "x", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 1/
      end

      it 'should cat first level of backtrace when --ex 0 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 0"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 1"
          f.flush
          pry_instance.last_exception = MockPryException.new("#{f.path}:1", "x", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 1/
      end

      it 'should cat second level of backtrace when --ex 1 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 1"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 2"
          f.flush
          pry_instance.last_exception = MockPryException.new("x", "#{f.path}:1", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 2/
      end

      it 'should cat third level of backtrace when --ex 2 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 2"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 3"
          f.flush
          pry_instance.last_exception = MockPryException.new("x", "x", "#{f.path}:1")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 3/
      end

      it 'should show error when backtrace level out of bounds  ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 3"), :output => str_output = StringIO.new)
        pry_instance.last_exception = MockPryException.new("x", "x", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /No Exception or Exception has no associated file/
      end

      it 'each successive cat --ex should show the next level of backtrace, and going past the final level should return to the first' do
        temp_files = []
        3.times do |i|
          temp_files << Tempfile.new(['tmp', '*.rb'])
          temp_files.last << "bt number #{i}"
          temp_files.last.flush
        end

        pry_instance = Pry.new(:input => StringIO.new("cat --ex\n" * 4),
                               :output => (str_output = StringIO.new))

        pry_instance.last_exception = MockPryException.new(*temp_files.map { |f| "#{f.path}:1" })

        3.times do |i|
          pry_instance.rep(self)
          str_output.string.should =~ /bt number #{i}/
        end

        str_output.reopen
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 0/

        temp_files.each(&:close)
      end

    end
  end
end
