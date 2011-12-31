require 'helper'

describe "Pry::Command" do

  before do
    @set = Pry::CommandSet.new
  end

  describe 'call_safely' do

    it 'should display a message if gems are missing' do
      cmd = @set.command_class "ford-prefect", "From a planet near Beetlegeuse", :requires_gem => %w(ghijkl) do
        #
      end

      mock_command(cmd, %w(hello world)).output.should =~ /install-command ford-prefect/
    end

    it 'should abort early if arguments are required' do
      cmd = @set.command_class 'arthur-dent', "Doesn't understand Thursdays", :argument_required => true do
        #
      end

      lambda {
        mock_command(cmd, %w())
      }.should.raise(Pry::CommandError)
    end

    it 'should return VOID without keep_retval' do
      cmd = @set.command_class 'zaphod-beeblebrox', "Likes pan-Galactic Gargle Blasters" do
        def process
          3
        end
      end

      mock_command(cmd).return.should == Pry::Command::VOID_VALUE
    end

    it 'should return the return value with keep_retval' do
      cmd = @set.command_class 'tricia-mcmillian', "a.k.a Trillian", :keep_retval => true do
        def process
          5
        end
      end

      mock_command(cmd).return.should == 5
    end

    it 'should call hooks in the right order' do
      cmd = @set.command_class 'marvin', "Pained by the diodes in his left side" do
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
      cmd = @set.command_class 'slartibartfast', "Designs Fjords", :keep_retval => true do
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
      @set.command_class 'eddie', "The ship-board computer" do
        def options(opt)
          opt.banner "Over-cheerful, and makes a ticking noise."
        end
      end

      mock_command(@set.commands['help'], %w(eddie), :command_set => @set).output.should =~ /Over-cheerful/
    end

    it 'should provide --help for classy commands' do
      cmd = @set.command_class 'agrajag', "Killed many times by Arthur" do
        def options(opt)
          opt.on :r, :retaliate, "Try to get Arthur back"
        end
      end

      mock_command(cmd, %w(--help)).output.should =~ /--retaliate/
    end

    it 'should provide a -h for classy commands' do
      cmd = @set.command_class 'zarniwoop', "On an intergalactic cruise, in his office." do
        def options(opt)
          opt.on :e, :escape, "Help zaphod escape the Total Perspective Vortex"
        end
      end

      mock_command(cmd, %w(--help)).output.should =~ /Total Perspective Vortex/
    end
  end


  describe 'context' do
    context = {
      :target => binding,
      :output => StringIO.new,
      :captures => [],
      :eval_string => "eval-string",
      :arg_string => "arg-string",
      :command_set => @set,
      :pry_instance => Object.new,
      :command_processor => Object.new
    }

    it 'should capture lots of stuff from the hash passed to new before setup' do
      cmd = @set.command_class 'fenchurch', "Floats slightly off the ground" do
        define_method(:setup) do
          self.context.should == context
          target.should == context[:target]
          target_self.should == context[:target].eval('self')
          output.should == context[:output]
        end

        define_method(:process) do
          captures.should.equal?(context[:captures])
          eval_string.should == "eval-string"
          arg_string.should == "arg-string"
          command_set.should == @set
          _pry_.should == context[:pry_instance]
          command_processor.should == context[:command_processor]
        end
      end

      cmd.new(context).call
    end
  end

  describe 'classy api' do

    it 'should call setup, then options, then process' do
      cmd = @set.command_class 'rooster', "Has a tasty towel" do
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
      cmd = @set.command_class 'jeltz', "Commander of a Vogon constructor fleet" do
        def proccces
          #
        end
      end

      lambda {
        mock_command(cmd)
      }.should.raise(Pry::CommandError)
    end

    it 'should work if neither options, nor setup is overridden' do
      cmd = @set.command_class 'wowbagger', "Immortal, insulting.", :keep_retval => true do
        def process
          5
        end
      end

      mock_command(cmd).return.should == 5
    end

    it 'should provide opts and args as provided by slop' do
      cmd = @set.command_class 'lintilla', "One of 800,000,000 clones" do
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
  end
end
