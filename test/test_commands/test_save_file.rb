require 'helper'
require 'fileutils'

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

    it "should display a success message on save" do
      @t.eval ':horse_nostrils'
      @t.eval("save-file -i 1 #{@path}").should =~ /successfully saved/
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

      it "should display a success message on save" do
        @t.eval("save-file #{@path} -m baby").should =~ /successfully saved/
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

  describe "save-file without path should save anyway" do
    before do
      @save_dir = "/tmp/pry-save"
      Pry.config.save_file_path = @save_dir

      @t = pry_tester
    end

    describe "asks for input if directory doesn't exist" do
      before do
        FileUtils.rm_rf @save_dir
      end

      ["y", "Y", ""].each do |correct_input|
        it "creates the directory if it doesn't exist and input is #{correct_input}" do
          @t.eval ':horse_nostrils'
          File.directory?(@save_dir).should == false
          InputFaker.with_fake_input(@t.pry, "#{correct_input}\n") do
            @t.eval "save-file -i 1"
          end
          File.directory?(@save_dir).should == true
        end
      end

      ["n", "N", "please?"].each do |invalid_input|
        it "doesn't create the directory if input is #{invalid_input}" do
          @t.eval ':horse_nostrils'
          File.directory?(@save_dir).should == false
          lambda do
            InputFaker.with_fake_input(@t.pry, "#{invalid_input}\n") do
              @t.eval "save-file -i 1"
            end
          end.should.raise Pry::CommandError
        end
      end
    end

    describe "generate right filename with all options" do
      before do
        Dir.mkdir(@save_dir) unless File.directory?(@save_dir)
      end

      after do
        FileUtils.rm_rf @save_dir
      end

      it "should never generate twice the same filename" do
        @t.eval("def tata; p 'tata'; end;")
        generated_filename = "#{@save_dir}/tata.rb"
        @t.eval("save-file -m tata").should =~ /^#{generated_filename}/
        @t.eval("save-file -m tata").should =~ /^#{@save_dir}\/tata-\d{10}\.rb/
      end

      it "should work with -f" do
        temp_file do |f|
          path = f.path
          f.puts ":cute_horse"
          f.flush
          generated_filename = "#{@save_dir}/#{File.basename(path)}"
          @t.eval("save-file -f #{path}").should =~ /^#{generated_filename}/
        end
      end

      it "should work with -i" do
        @t.eval ':horse_nostrils'
        generated_filename = "#{@save_dir}/input_history.rb"
        @t.eval("save-file -i 1").should =~ /^#{generated_filename}/
      end

      it "should work with -m" do
        @t.eval("def toto; p 'toto'; end; def titi; p 'titi'; end;")

        generated_filename = "#{@save_dir}/toto.rb"
        @t.eval("save-file -m toto").should =~ /^#{generated_filename}/

        generated_filename = "#{@save_dir}/toto-titi.rb"
        @t.eval("save-file -m toto -m titi").should =~ /^#{generated_filename}/
      end

      it "should work with -k" do
        generated_filename = "#{@save_dir}/show-method.rb"
        @t.eval("save-file -k show-method").should =~ /^#{generated_filename}/
      end

      it "should work with -o" do
        generated_filename = "#{@save_dir}/output_history.rb"
        @t.eval("save-file -o -1..1").should =~ /^#{generated_filename}/
      end

      it "should work with combined options" do
        @t.eval("def toto; p 'toto'; end; def titi; p 'titi'; end;")
        generated_filename = "#{@save_dir}/input_history-toto-output_history.rb"
        @t.eval("save-file -i 1 -m toto -o -3..1").should =~ /^#{generated_filename}/
      end
    end

  end
end

