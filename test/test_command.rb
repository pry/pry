require 'helper'

describe "Pry::Command" do

  before do
    @set = Pry::CommandSet.new
  end

  describe 'call_safely' do

    it 'should display a message if gems are missing' do
      cmd = @set.create_command "ford-prefect", "From a planet near Beetlegeuse", :requires_gem => %w(ghijkl) do
        #
      end

      mock_command(cmd, %w(hello world)).output.should =~ /install-command ford-prefect/
    end

    it 'should abort early if arguments are required' do
      cmd = @set.create_command 'arthur-dent', "Doesn't understand Thursdays", :argument_required => true do
        #
      end

      lambda {
        mock_command(cmd, %w())
      }.should.raise(Pry::CommandError)
    end

    it 'should return VOID without keep_retval' do
      cmd = @set.create_command 'zaphod-beeblebrox', "Likes pan-Galactic Gargle Blasters" do
        def process
          3
        end
      end

      mock_command(cmd).return.should == Pry::Command::VOID_VALUE
    end

    it 'should return the return value with keep_retval' do
      cmd = @set.create_command 'tricia-mcmillian', "a.k.a Trillian", :keep_retval => true do
        def process
          5
        end
      end

      mock_command(cmd).return.should == 5
    end

    it 'should call hooks in the right order' do
      cmd = @set.create_command 'marvin', "Pained by the diodes in his left side" do
        def process
          output.puts 3 + args[0].to_i
        end
      end

      @set.before_command 'marvin' do |i|
        output.puts 2 + i.to_i
      end
      @set.before_command 'marvin' do |i|
        output.puts 1 + i.to_i
      end

      @set.after_command 'marvin' do |i|
        output.puts 4 + i.to_i
      end

      @set.after_command 'marvin' do |i|
        output.puts 5 + i.to_i
      end

      mock_command(cmd, %w(2)).output.should == "3\n4\n5\n6\n7\n"
    end

    # TODO: This strikes me as rather silly...
    it 'should return the value from the last hook with keep_retval' do
      cmd = @set.create_command 'slartibartfast', "Designs Fjords", :keep_retval => true do
        def process
          22
        end
      end

      @set.after_command 'slartibartfast' do
        10
      end

      mock_command(cmd).return.should == 10
    end
  end

  describe 'help' do
    it 'should default to the description for blocky commands' do
      @set.command 'oolon-colluphid', "Raving Atheist" do
        #
      end

      mock_command(@set.commands['help'], %w(oolon-colluphid), :command_set => @set).output.should =~ /Raving Atheist/
    end

    it 'should use slop to generate the help for classy commands' do
      @set.create_command 'eddie', "The ship-board computer" do
        def options(opt)
          opt.banner "Over-cheerful, and makes a ticking noise."
        end
      end

      mock_command(@set.commands['help'], %w(eddie), :command_set => @set).output.should =~ /Over-cheerful/
    end

    it 'should provide --help for classy commands' do
      cmd = @set.create_command 'agrajag', "Killed many times by Arthur" do
        def options(opt)
          opt.on :r, :retaliate, "Try to get Arthur back"
        end
      end

      mock_command(cmd, %w(--help)).output.should =~ /--retaliate/
    end

    it 'should provide a -h for classy commands' do
      cmd = @set.create_command 'zarniwoop', "On an intergalactic cruise, in his office." do
        def options(opt)
          opt.on :e, :escape, "Help zaphod escape the Total Perspective Vortex"
        end
      end

      mock_command(cmd, %w(--help)).output.should =~ /Total Perspective Vortex/
    end

    it 'should use the banner provided' do
      cmd = @set.create_command 'deep-thought', "The second-best computer ever" do
        banner <<-BANNER
          Who's merest operational parameters, I am not worthy to compute.
        BANNER
      end

      mock_command(cmd, %w(--help)).output.should =~ /Who\'s merest/
    end
  end


  describe 'context' do
    context = {
      :target => binding,
      :output => StringIO.new,
      :eval_string => "eval-string",
      :command_set => @set,
      :pry_instance => Object.new
    }

    it 'should capture lots of stuff from the hash passed to new before setup' do
      cmd = @set.create_command 'fenchurch', "Floats slightly off the ground" do
        define_method(:setup) do
          self.context.should == context
          target.should == context[:target]
          target_self.should == context[:target].eval('self')
          output.should == context[:output]
        end

        define_method(:process) do
          eval_string.should == "eval-string"
          command_set.should == @set
          _pry_.should == context[:pry_instance]
        end
      end

      cmd.new(context).call
    end
  end

  describe 'classy api' do

    it 'should call setup, then options, then process' do
      cmd = @set.create_command 'rooster', "Has a tasty towel" do
        def setup
          output.puts "setup"
        end

        def options(opt)
          output.puts "options"
        end

        def process
          output.puts "process"
        end
      end

      mock_command(cmd).output.should == "setup\noptions\nprocess\n"
    end

    it 'should raise a command error if process is not overridden' do
      cmd = @set.create_command 'jeltz', "Commander of a Vogon constructor fleet" do
        def proccces
          #
        end
      end

      lambda {
        mock_command(cmd)
      }.should.raise(Pry::CommandError)
    end

    it 'should work if neither options, nor setup is overridden' do
      cmd = @set.create_command 'wowbagger', "Immortal, insulting.", :keep_retval => true do
        def process
          5
        end
      end

      mock_command(cmd).return.should == 5
    end

    it 'should provide opts and args as provided by slop' do
      cmd = @set.create_command 'lintilla', "One of 800,000,000 clones" do
         def options(opt)
           opt.on :f, :four, "A numeric four", :as => Integer, :optional => true
         end

         def process
           args.should == ['four']
           opts[:f].should == 4
         end
      end

      mock_command(cmd, %w(--four 4 four))
    end

    it 'should allow overriding options after definition' do
      cmd = @set.create_command /number-(one|two)/, "Lieutenants of the Golgafrinchan Captain", :shellwords => false do

        command_options :listing => 'number-one'
      end

      cmd.command_options[:shellwords].should == false
      cmd.command_options[:listing].should == 'number-one'
    end
  end

  describe 'tokenize' do
    it 'should interpolate string with #{} in them' do
      cmd = @set.command 'random-dent' do |*args|
        args.should == ["3", "8"]
      end

      foo = 5

      cmd.new(:target => binding).process_line 'random-dent #{1 + 2} #{3 + foo}'
    end

    it 'should not fail if interpolation is not needed and target is not set' do
      cmd = @set.command 'the-book' do |*args|
        args.should == ['--help']
      end

      cmd.new.process_line 'the-book --help'
    end

    it 'should not interpolate commands with :interpolate => false' do
      cmd = @set.command 'thor', 'norse god', :interpolate => false do |*args|
        args.should == ['%(#{foo})']
      end

      cmd.new.process_line 'thor %(#{foo})'
    end

    it 'should use shell-words to split strings' do
      cmd = @set.command 'eccentrica' do |*args|
        args.should == ['gallumbits', 'eroticon', '6']
      end

      cmd.new.process_line %(eccentrica "gallumbits" 'erot''icon' 6)
    end

    it 'should split on spaces if shellwords is not used' do
      cmd = @set.command 'bugblatter-beast', 'would eat its grandmother', :shellwords => false do |*args|
        args.should == ['"of', 'traal"']
      end

      cmd.new.process_line %(bugblatter-beast "of traal")
    end

    it 'should add captures to arguments for regex commands' do
      cmd = @set.command /perfectly (normal)( beast)?/i do |*args|
        args.should == ['Normal', ' Beast', '(honest!)']
      end

      cmd.new.process_line %(Perfectly Normal Beast (honest!))
    end
  end

  describe 'process_line' do
    it 'should check for command name collisions if configured' do
      old = Pry.config.collision_warning
      Pry.config.collision_warning = true

      cmd = @set.command 'frankie' do

      end

      frankie = 'boyle'
      output = StringIO.new
      cmd.new(:target => binding, :output => output).process_line %(frankie mouse)

      output.string.should =~ /Command name collision/

      Pry.config.collision_warning = old
    end

    it "should set the commands' arg_string and captures" do

      cmd = @set.command /benj(ie|ei)/ do |*args|
        self.arg_string.should == "mouse"
        self.captures.should == ['ie']
        args.should == ['ie', 'mouse']
      end

      cmd.new.process_line %(benjie mouse)
    end

    it "should raise an error if the line doesn't match the command" do
      cmd = @set.command 'grunthos', 'the flatulent'

      lambda {
        cmd.new.process_line %(grumpos)
      }.should.raise(Pry::CommandError)
    end
  end
end
