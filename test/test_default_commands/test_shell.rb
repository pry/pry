require 'helper'

describe "Pry::DefaultCommands::Shell" do
  describe "save-file" do
    before do
      @tf = Tempfile.new(["pry", ".py"])
      @path = @tf.path
    end

    after do
      @tf.close(true)
    end

    describe "-f" do
      it 'should save a file to a file' do
        f = Tempfile.new(["pry", ".py"])
        path = f.path
        f.write ":cute_horse"

        redirect_pry_io(InputTester.new("save-file -f #{path} #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end
        File.read(@path).should == File.read(path)

        f.close(true)
      end
    end

    describe "-i" do
      it 'should save input expressions to a file (single expression)' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        "save-file -i 1 #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end
        File.read(@path).should == ":horse_nostrils\n"
      end

      it 'should save input expressions to a file (range)' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        ":sucking_up_all_the_oxygen",
                                        "save-file -i 1..2 #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end
        File.read(@path).should == ":horse_nostrils\n:sucking_up_all_the_oxygen\n"
      end
    end

    describe "-m" do
      before do
        @o = Object.new
        def @o.baby
          :baby
        end
        def @o.bang
          :bang
        end
      end

      describe "single method" do
        it 'should save a method to a file' do
          redirect_pry_io(InputTester.new("save-file #{@path} -m baby",
                                          "exit-all")) do
            Pry.start(@o)
          end
          File.read(@path).should == Pry::Method.from_obj(@o, :baby).source
        end

        it 'should save a method to a file truncated by --lines' do
          redirect_pry_io(InputTester.new("save-file #{@path} -m baby --lines 2..4",
                                          "exit-all")) do
            Pry.start(@o)
          end

          # must add 1 as first line of method is 1
          File.read(@path).should == Pry::Method.from_obj(@o, :baby).source.lines.to_a[1..5].join
        end
      end

      describe "multiple method" do
        it 'should save multiple methods to a file' do
          redirect_pry_io(InputTester.new("save-file #{@path} -m baby -m bang",
                                          "exit-all")) do
            Pry.start(@o)
          end
          File.read(@path).should == Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source
        end

        it 'should save multiple methods to a file trucated by --lines' do
          redirect_pry_io(InputTester.new("save-file #{@path} -m baby -m bang --lines 2..-2",
                                          "exit-all")) do
            Pry.start(@o)
          end

          # must add 1 as first line of method is 1
          File.read(@path).should == (Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source).lines.to_a[1..-2].join
        end

        it 'should save multiple methods to a file trucated by --lines 1 (single parameter, not range)' do
          redirect_pry_io(InputTester.new("save-file #{@path} -m baby -m bang --lines 1",
                                          "exit-all")) do
            Pry.start(@o)
          end

          # must add 1 as first line of method is 1
          File.read(@path).should == (Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source).lines.to_a[0]
        end

      end

    end

    describe "overwrite by default (no --append)" do
      it 'should overwrite specified file with new input' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        "save-file -i 1 #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end

        redirect_pry_io(InputTester.new(":sucking_up_all_the_oxygen",
                                        "save-file -i 1 #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end

        File.read(@path).should == ":sucking_up_all_the_oxygen\n"
      end

    end

    describe "--append" do
      it 'should append to end of specified file' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        "save-file -i 1 #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end

        redirect_pry_io(InputTester.new(":sucking_up_all_the_oxygen",
                                        "save-file -i 1 #{@path} -a",
                                        "exit-all")) do
          Pry.start(@o)
        end

        File.read(@path).should == ":horse_nostrils\n:sucking_up_all_the_oxygen\n"
      end
    end

    describe "-c" do
      it 'should save a command to a file' do
        redirect_pry_io(InputTester.new("save-file #{@path} -c show-method",
                                        "exit-all")) do
          Pry.start(@o)
        end
        cmd = Pry::Method.new(Pry.commands.find_command("show-method").block)
        File.read(@path).should == Pry::Code.from_method(cmd).to_s
      end
    end

    describe "combined options" do
      before do
        @o = Object.new
        def @o.baby
          :baby
        end
      end

      it 'should save input cache and a method to a file (in that order)' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        "save-file -i 1 -m baby #{@path}",
                                        "exit-all")) do
          Pry.start(@o)
        end
        File.read(@path).should == ":horse_nostrils\n" + Pry::Method.from_obj(@o, :baby).source
      end

      it 'should select a portion to save using --lines' do
        redirect_pry_io(InputTester.new(":horse_nostrils",
                                        "save-file -i 1 -m baby #{@path} --lines 2..-2",
                                        "exit-all")) do
          Pry.start(@o)
        end
        File.read(@path).should == (":horse_nostrils\n" + Pry::Method.from_obj(@o, :baby).source).lines.to_a[1..-2].join
      end
    end
  end

  describe "cat" do

    describe "on receiving a file that does not exist" do
      it 'should display an error message' do
        mock_pry("cat supercalifragilicious66").should =~ /Cannot open/
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
      if !Pry::Helpers::BaseHelpers.rbx?
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
          pry_instance.last_exception = mock_exception("#{f.path}:1", "x", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 1/
      end

      it 'should cat first level of backtrace when --ex 0 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 0"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 1"
          f.flush
          pry_instance.last_exception = mock_exception("#{f.path}:1", "x", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 1/
      end

      it 'should cat second level of backtrace when --ex 1 used ' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 1"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 2"
          f.flush
          pry_instance.last_exception = mock_exception("x", "#{f.path}:1", "x")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 2/
      end

      it 'should cat third level of backtrace when --ex 2 used' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 2"), :output => str_output = StringIO.new)

        temp_file do |f|
          f << "bt number 3"
          f.flush
          pry_instance.last_exception = mock_exception("x", "x", "#{f.path}:1")
          pry_instance.rep(self)
        end

        str_output.string.should =~ /bt number 3/
      end

      it 'should show error when backtrace level out of bounds' do
        pry_instance = Pry.new(:input => StringIO.new("cat --ex 3"), :output => str_output = StringIO.new)
        pry_instance.last_exception = mock_exception("x", "x", "x")
        pry_instance.rep(self)
        str_output.string.should =~ /out of bounds/
      end

      it 'each successive cat --ex should show the next level of backtrace, and going past the final level should return to the first' do
        temp_files = []
        3.times do |i|
          temp_files << Tempfile.new(['pry', '*.rb'])
          temp_files.last << "bt number #{i}"
          temp_files.last.flush
        end

        pry_instance = Pry.new(:input => StringIO.new("cat --ex\n" * 4),
                               :output => (str_output = StringIO.new))

        pry_instance.last_exception = mock_exception(*temp_files.map { |f| "#{f.path}:1" })

        3.times do |i|
          pry_instance.rep(self)
          str_output.string.should =~ /bt number #{i}/
        end

        str_output.reopen
        pry_instance.rep(self)
        str_output.string.should =~ /bt number 0/

        temp_files.each do |file|
          file.close(true)
        end
      end

    end
  end
end
