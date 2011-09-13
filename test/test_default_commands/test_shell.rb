require 'helper'

describe "Pry::DefaultCommands::Shell" do
  describe "cat" do

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
        file_name = temp_file do |f|
          f << "bt number 1"
        end
        pry_instance.last_exception = MockPryException.new("#{file_name}:1", "x", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 1/
      end

      it 'should cat first level of backtrace when --ex 0 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 0"), :output => str_output = StringIO.new)
        file_name = temp_file do |f|
          f << "bt number 1"
        end
        pry_instance.last_exception = MockPryException.new("#{file_name}:1", "x", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 1/
      end

      it 'should cat second level of backtrace when --ex 1 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 1"), :output => str_output = StringIO.new)
        file_name = temp_file do |f|
          f << "bt number 2"
        end
        pry_instance.last_exception = MockPryException.new("x", "#{file_name}:1", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 2/
      end

      it 'should cat third level of backtrace when --ex 2 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 2"), :output => str_output = StringIO.new)
        file_name = temp_file do |f|
          f << "bt number 3"
        end
        pry_instance.last_exception = MockPryException.new("x", "x", "#{file_name}:1")
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 3/
      end

      it 'should show error when backtrace level out of bounds  ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 3"), :output => str_output = StringIO.new)
        pry_instance.last_exception = MockPryException.new("x", "x", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /No Exception or Exception has no associated file/
      end

      it 'each successive cat --ex should show the next level of backtrace, and going past the final level should return to the first' do
        file_names = []
        file_names << temp_file { |f| f << "bt number 0" }
        file_names << temp_file { |f| f << "bt number 1" }
        file_names << temp_file { |f| f << "bt number 2" }

        pry_instance = Pry.new(:input => StringIO.new("cat --ex\n" * (file_names.size + 1)),
                               :output => str_output = StringIO.new)

        pry_instance.last_exception = MockPryException.new(*file_names.map { |f| "#{f}:1" })

        file_names.each_with_index do |f, idx|
          pry_instance.rep(self)
          str_output.string.should =~ /bt number #{idx}/
        end

        str_output.reopen
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 0/
      end

    end
  end
end
