require 'helper'

describe "Pry::DefaultCommands::Shell" do
  describe "save-file" do
    before do
      @tf = Tempfile.new(["pry", ".py"])
      @path = @tf.path
      @t = pry_tester
    end

    after do
      @tf.close(true)
    end

    describe "-f" do
      it 'should save a file to a file' do
        temp_file do |f|
          path = f.path
          f.puts ":cute_horse"
          f.flush

          @t.eval("save-file -f #{path} #{@path}")

          File.read(@path).should == File.read(path)
        end
      end
    end

    describe "-i" do
      it 'should save input expressions to a file (single expression)' do
        @t.eval ':horse_nostrils'
        @t.eval "save-file -i 1 #{@path}"
        File.read(@path).should == ":horse_nostrils\n"
      end

      it 'should save input expressions to a file (range)' do
        @t.eval ':or_nostrils', ':sucking_up_all_the_oxygen', ':or_whatever'
        @t.eval "save-file -i 1..2 #{@path}"
        File.read(@path).should == ":or_nostrils\n:sucking_up_all_the_oxygen\n"
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

        @t = pry_tester(@o)
      end

      describe "single method" do
        it 'should save a method to a file' do
          @t.eval "save-file #{@path} -m baby"
          File.read(@path).should == Pry::Method.from_obj(@o, :baby).source
        end

        it 'should save a method to a file truncated by --lines' do
          @t.eval "save-file #{@path} -m baby --lines 2..4"

          # must add 1 as first line of method is 1
          File.read(@path).should ==
            Pry::Method.from_obj(@o, :baby).source.lines.to_a[1..5].join
        end
      end

      describe "multiple method" do
        it 'should save multiple methods to a file' do
          @t.eval "save-file #{@path} -m baby -m bang"

          File.read(@path).should == Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source
        end

        it 'should save multiple methods to a file trucated by --lines' do
          @t.eval "save-file #{@path} -m baby -m bang --lines 2..-2"

          # must add 1 as first line of method is 1
          File.read(@path).should == (Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source).lines.to_a[1..-2].join
        end

        it 'should save multiple methods to a file trucated by --lines 1 ' \
           '(single parameter, not range)' do
          @t.eval "save-file #{@path} -m baby -m bang --lines 1"

          # must add 1 as first line of method is 1
          File.read(@path).should == (Pry::Method.from_obj(@o, :baby).source +
            Pry::Method.from_obj(@o, :bang).source).lines.to_a[0]
        end
      end
    end

    describe "overwrite by default (no --append)" do
      it 'should overwrite specified file with new input' do
        @t.eval ':horse_nostrils'
        @t.eval "save-file -i 1 #{@path}"

        @t.eval ':sucking_up_all_the_oxygen'
        @t.eval "save-file -i 2 #{@path}"

        File.read(@path).should == ":sucking_up_all_the_oxygen\n"
      end
    end

    describe "--append" do
      it 'should append to end of specified file' do
        @t.eval ':horse_nostrils'
        @t.eval "save-file -i 1 #{@path}"

        @t.eval ':sucking_up_all_the_oxygen'
        @t.eval "save-file -i 2 #{@path} -a"

        File.read(@path).should ==
          ":horse_nostrils\n:sucking_up_all_the_oxygen\n"
      end
    end

    describe "-c" do
      it 'should save a command to a file' do
        @t.eval "save-file #{@path} -k show-method"
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

        @t = pry_tester(@o)
      end

      it 'should save input cache and a method to a file (in that order)' do
        @t.eval ":horse_nostrils"
        @t.eval "save-file -i 1 -m baby #{@path}"

        File.read(@path).should == ":horse_nostrils\n" +
          Pry::Method.from_obj(@o, :baby).source
      end

      it 'should select a portion to save using --lines' do
        @t.eval ":horse_nostrils"
        @t.eval "save-file -i 1 -m baby #{@path} --lines 2..-2"

        str = ":horse_nostrils\n" + Pry::Method.from_obj(@o, :baby).source
        File.read(@path).should == str.lines.to_a[1..-2].join
      end
    end
  end

  describe "cat" do
    before do
      @str_output = StringIO.new

      @t = pry_tester do
        def insert_nil_input
          @pry.update_input_history(nil)
        end

        def last_exception=(e)
          @pry.last_exception = e
        end
      end
    end

    describe "on receiving a file that does not exist" do
      it 'should display an error message' do
        proc {
          @t.eval 'cat supercalifragilicious66'
        }.should.raise(StandardError).message.should =~ /Cannot open/
      end
    end

    describe "with --in" do
      it 'should display the last few expressions with indices' do
        @t.eval('10', '20', 'cat --in').should == unindent(<<-STR)
          1:
            10
          2:
            20
        STR
      end
    end

    describe "with --in 1" do
      it 'should display the first expression with no index' do
        @t.eval('10', '20', 'cat --in 1').should == "10\n"
      end
    end

    describe "with --in -1" do
      it 'should display the last expression with no index' do
        @t.eval('10', '20', 'cat --in -1').should == "20\n"
      end
    end

    describe "with --in 1..2" do
      it 'should display the given range with indices, omitting nils' do
        @t.eval '10'
        @t.insert_nil_input # normally happens when a command is executed
        @t.eval ':hello'

        @t.eval('cat --in 1..3').should == unindent(<<-EOS)
          1:
            10
          3:
            :hello
        EOS
      end
    end

    # this doesnt work so well on rbx due to differences in backtrace
    # so we currently skip rbx until we figure out a workaround
    describe "with --ex" do
      if !Pry::Helpers::BaseHelpers.rbx?
        it 'cat --ex should display repl code that generated exception' do
          @t.eval unindent(<<-EOS)
            begin
              this raises error
            rescue => e
              _pry_.last_exception = e
            end
          EOS
          @t.eval('cat --ex').should =~ /\d+:(\s*) this raises error/
        end

        it 'cat --ex should correctly display code that generated exception' do
          begin
            broken_method
          rescue => e
            @t.last_exception = e
          end
          @t.eval('cat --ex').should =~ /this method is broken/
        end
      end
    end

    describe "with --ex N" do
      it 'should cat first level of backtrace when --ex used with no argument ' do
        temp_file do |f|
          f << "bt number 1"
          f.flush
          @t.last_exception = mock_exception("#{f.path}:1", 'x', 'x')
          @t.eval('cat --ex').should =~ /bt number 1/
        end
      end

      it 'should cat first level of backtrace when --ex 0 used ' do
        temp_file do |f|
          f << "bt number 1"
          f.flush
          @t.last_exception = mock_exception("#{f.path}:1", 'x', 'x')
          @t.eval('cat --ex 0').should =~ /bt number 1/
        end
      end

      it 'should cat second level of backtrace when --ex 1 used ' do
        temp_file do |f|
          f << "bt number 2"
          f.flush
          @t.last_exception = mock_exception('x', "#{f.path}:1", 'x')
          @t.eval('cat --ex 1').should =~ /bt number 2/
        end
      end

      it 'should cat third level of backtrace when --ex 2 used' do
        temp_file do |f|
          f << "bt number 3"
          f.flush
          @t.last_exception = mock_exception('x', 'x', "#{f.path}:1")
          @t.eval('cat --ex 2').should =~ /bt number 3/
        end
      end

      it 'should show error when backtrace level out of bounds' do
        @t.last_exception = mock_exception('x', 'x', 'x')
        proc {
          @t.eval('cat --ex 3')
        }.should.raise(Pry::CommandError).message.should =~ /out of bounds/
      end

      it 'each successive cat --ex should show the next level of backtrace, and going past the final level should return to the first' do
        temp_files = []
        3.times do |i|
          temp_files << Tempfile.new(['pry', '*.rb'])
          temp_files.last << "bt number #{i}"
          temp_files.last.flush
        end

        @t.last_exception = mock_exception(*temp_files.map { |f| "#{f.path}:1" })

        3.times do |i|
          @t.eval('cat --ex').should =~ /bt number #{i}/
        end

        @t.eval('cat --ex').should =~ /bt number 0/

        temp_files.each do |file|
          file.close(true)
        end
      end
    end
  end
end
