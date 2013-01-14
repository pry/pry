require 'helper'

describe "Pry::Command" do

  before do
    @set = Pry::CommandSet.new
    @set.import Pry::Commands
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

    it 'should call setup, then subcommands, then options, then process' do
      cmd = @set.create_command 'rooster', "Has a tasty towel" do
        def setup
          output.puts "setup"
        end

        def subcommands(cmd)
          output.puts "subcommands"
        end

        def options(opt)
          output.puts "options"
        end

        def process
          output.puts "process"
        end
      end

      mock_command(cmd).output.should == "setup\nsubcommands\noptions\nprocess\n"
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
          opt.on :f, :four, "A numeric four", :as => Integer, :optional_argument => true
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

    it "should create subcommands" do
      cmd = @set.create_command 'mum', 'Your mum' do
        def subcommands(cmd)
          cmd.command :yell
        end

        def process
          opts.fetch_command(:blahblah).should == nil
          opts.fetch_command(:yell).present?.should == true
        end
      end

      mock_command(cmd, ['yell'])
    end

    it "should create subcommand options" do
      cmd = @set.create_command 'mum', 'Your mum' do
        def subcommands(cmd)
          cmd.command :yell do
            on :p, :person
          end
        end

        def process
          args.should == ['papa']
          opts.fetch_command(:yell).present?.should == true
          opts.fetch_command(:yell).person?.should == true
        end
      end

      mock_command(cmd, %w|yell --person papa|)
    end

    it "should accept top-level arguments" do
      cmd = @set.create_command 'mum', 'Your mum' do
        def subcommands(cmd)
          cmd.on :yell
        end

        def process
          args.should == ['yell', 'papa', 'sonny', 'daughter']
        end
      end

      mock_command(cmd, %w|yell papa sonny daughter|)
    end

    describe "explicit classes" do
      before do
        @x = Class.new(Pry::ClassCommand) do
          options :baby => :pig
          match /goat/
          description "waaaninngggiiigygygygygy"
        end
      end

      it 'subclasses should inherit options, match and description from superclass' do
        k = Class.new(@x)
        k.options.should == @x.options
        k.match.should == @x.match
        k.description.should == @x.description
      end
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

      output.string.should =~ /command .* conflicts/

      Pry.config.collision_warning = old
    end

    it 'should spot collision warnings on assignment if configured' do
      old = Pry.config.collision_warning
      Pry.config.collision_warning = true

      cmd = @set.command 'frankie' do

      end

      output = StringIO.new
      cmd.new(:target => binding, :output => output).process_line %(frankie = mouse)

      output.string.should =~ /command .* conflicts/

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

  describe "block parameters" do
    before do
      @context = Object.new
      @set.command "walking-spanish", "down the hall", :takes_block => true do
        PryTestHelpers.inject_var(:@x, command_block.call, target)
      end
      @set.import Pry::Commands

      @t = pry_tester(@context, :commands => @set)
    end

    it 'should accept multiline blocks' do
      @t.eval <<-EOS
        walking-spanish | do
          :jesus
        end
      EOS

      @context.instance_variable_get(:@x).should == :jesus
    end

    it 'should accept normal parameters along with block' do
      @set.block_command "walking-spanish",
          "litella's been screeching for a blind pig.",
          :takes_block => true do |x, y|
        PryTestHelpers.inject_var(:@x, x, target)
        PryTestHelpers.inject_var(:@y, y, target)
        PryTestHelpers.inject_var(:@block_var, command_block.call, target)
      end

      @t.eval 'walking-spanish john carl| { :jesus }'

      @context.instance_variable_get(:@x).should == "john"
      @context.instance_variable_get(:@y).should == "carl"
      @context.instance_variable_get(:@block_var).should == :jesus
    end

    describe "single line blocks" do
      it 'should accept blocks with do ; end' do
        @t.eval 'walking-spanish | do ; :jesus; end'
        @context.instance_variable_get(:@x).should == :jesus
      end

      it 'should accept blocks with do; end' do
        @t.eval 'walking-spanish | do; :jesus; end'
        @context.instance_variable_get(:@x).should == :jesus
      end

      it 'should accept blocks with { }' do
        @t.eval 'walking-spanish | { :jesus }'
        @context.instance_variable_get(:@x).should == :jesus
      end
    end

    describe "block-related content removed from arguments" do

      describe "arg_string" do
        it 'should remove block-related content from arg_string (with one normal arg)' do
          @set.block_command "walking-spanish", "down the hall", :takes_block => true do |x, y|
            PryTestHelpers.inject_var(:@arg_string, arg_string, target)
            PryTestHelpers.inject_var(:@x, x, target)
          end

          @t.eval 'walking-spanish john| { :jesus }'

          @context.instance_variable_get(:@arg_string).should == @context.instance_variable_get(:@x)
        end

        it 'should remove block-related content from arg_string (with no normal args)' do
          @set.block_command "walking-spanish", "down the hall", :takes_block => true do
            PryTestHelpers.inject_var(:@arg_string, arg_string, target)
          end

          @t.eval 'walking-spanish | { :jesus }'

          @context.instance_variable_get(:@arg_string).should == ""
        end

        it 'should NOT remove block-related content from arg_string when :takes_block => false' do
          block_string = "| { :jesus }"
          @set.block_command "walking-spanish", "homemade special", :takes_block => false do
            PryTestHelpers.inject_var(:@arg_string, arg_string, target)
          end

          @t.eval "walking-spanish #{block_string}"

          @context.instance_variable_get(:@arg_string).should == block_string
        end
      end

      describe "args" do
        describe "block_command" do
          it "should remove block-related content from arguments" do
            @set.block_command "walking-spanish", "glass is full of sand", :takes_block => true do |x, y|
              PryTestHelpers.inject_var(:@x, x, target)
              PryTestHelpers.inject_var(:@y, y, target)
            end

            @t.eval 'walking-spanish | { :jesus }'

            @context.instance_variable_get(:@x).should == nil
            @context.instance_variable_get(:@y).should == nil
          end

          it "should NOT remove block-related content from arguments if :takes_block => false" do
            @set.block_command "walking-spanish", "litella screeching for a blind pig", :takes_block => false do |x, y|
              PryTestHelpers.inject_var(:@x, x, target)
              PryTestHelpers.inject_var(:@y, y, target)
            end

            @t.eval 'walking-spanish | { :jesus }'

            @context.instance_variable_get(:@x).should == "|"
            @context.instance_variable_get(:@y).should == "{"
          end
        end

        describe "create_command" do
          it "should remove block-related content from arguments" do
            @set.create_command "walking-spanish", "punk sanders carved one out of wood", :takes_block => true do
              def process(x, y)
                PryTestHelpers.inject_var(:@x, x, target)
                PryTestHelpers.inject_var(:@y, y, target)
              end
            end

            @t.eval 'walking-spanish | { :jesus }'

            @context.instance_variable_get(:@x).should == nil
            @context.instance_variable_get(:@y).should == nil
          end

          it "should NOT remove block-related content from arguments if :takes_block => false" do
            @set.create_command "walking-spanish", "down the hall", :takes_block => false do
              def process(x, y)
                PryTestHelpers.inject_var(:@x, x, target)
                PryTestHelpers.inject_var(:@y, y, target)
              end
            end

            @t.eval 'walking-spanish | { :jesus }'

            @context.instance_variable_get(:@x).should == "|"
            @context.instance_variable_get(:@y).should == "{"
          end
        end
      end
    end

    describe "blocks can take parameters" do
      describe "{} style blocks" do
        it 'should accept multiple parameters' do
          @set.block_command "walking-spanish", "down the hall", :takes_block => true do
            PryTestHelpers.inject_var(:@x, command_block.call(1, 2), target)
          end

          @t.eval 'walking-spanish | { |x, y| [x, y] }'

          @context.instance_variable_get(:@x).should == [1, 2]
        end
      end

      describe "do/end style blocks" do
        it 'should accept multiple parameters' do
          @set.create_command "walking-spanish", "litella", :takes_block => true do
            def process
              PryTestHelpers.inject_var(:@x, command_block.call(1, 2), target)
            end
          end

          @t.eval <<-EOS
            walking-spanish | do |x, y|
              [x, y]
            end
          EOS

          @context.instance_variable_get(:@x).should == [1, 2]
        end
      end
    end

    describe "closure behaviour" do
      it 'should close over locals in the definition context' do
        @t.eval 'var = :hello', 'walking-spanish | { var }'
        @context.instance_variable_get(:@x).should == :hello
      end
    end

    describe "exposing block parameter" do
      describe "block_command" do
        it "should expose block in command_block method" do
          @set.block_command "walking-spanish", "glass full of sand", :takes_block => true do
            PryTestHelpers.inject_var(:@x, command_block.call, target)
          end

          @t.eval 'walking-spanish | { :jesus }'

          @context.instance_variable_get(:@x).should == :jesus
        end
      end

      describe "create_command" do
        it "should NOT expose &block in create_command's process method" do
          @set.create_command "walking-spanish", "down the hall", :takes_block => true do
            def process(&block)
              block.call
            end
          end
          @out = StringIO.new

          proc {
            @t.eval 'walking-spanish | { :jesus }'
          }.should.raise(NoMethodError)
        end

        it "should expose block in command_block method" do
          @set.create_command "walking-spanish", "homemade special", :takes_block => true do
            def process
              PryTestHelpers.inject_var(:@x, command_block.call, target)
            end
          end

          @t.eval 'walking-spanish | { :jesus }'

          @context.instance_variable_get(:@x).should == :jesus
        end
      end
    end
  end

  describe "a command made with a custom sub-class" do

    before do
      class MyTestCommand < Pry::ClassCommand
        match /my-*test/
        description 'So just how many sound technicians does it take to' \
          'change a lightbulb? 1? 2? 3? 1-2-3? Testing?'
        options :shellwords => false, :listing => 'my-test'

        def process
          output.puts command_name * 2
        end
      end

      Pry.commands.add_command MyTestCommand
    end

    after do
      Pry.commands.delete 'my-test'
    end

    it "allows creation of custom subclasses of Pry::Command" do
      pry_eval('my---test').should =~ /my-testmy-test/
    end

    if !mri18_and_no_real_source_location?
      it "shows the source of the process method" do
        pry_eval('show-source my-test').should =~ /output.puts command_name/
      end
    end

    describe "command options hash" do
      it "is always present" do
        options_hash = {
          :requires_gem      => [],
          :keep_retval       => false,
          :argument_required => false,
          :interpolate       => true,
          :shellwords        => false,
          :listing           => 'my-test',
          :use_prefix        => true,
          :takes_block       => false
        }
        MyTestCommand.options.should == options_hash
      end

      describe ":listing option" do
        it "defaults to :match if not set explicitly" do
          class HappyNewYear < Pry::ClassCommand
            match 'happy-new-year'
            description 'Happy New Year 2013'
          end
          Pry.commands.add_command HappyNewYear

          HappyNewYear.options[:listing].should == 'happy-new-year'

          Pry.commands.delete 'happy-new-year'
        end

        it "can be set explicitly" do
          class MerryChristmas < Pry::ClassCommand
            match 'merry-christmas'
            description 'Merry Christmas!'
            command_options :listing => 'happy-holidays'
          end
          Pry.commands.add_command MerryChristmas

          MerryChristmas.options[:listing].should == 'happy-holidays'

          Pry.commands.delete 'merry-christmas'
        end

        it "equals to :match option's inspect, if :match is Regexp" do
          class CoolWinter < Pry::ClassCommand
            match /.*winter/
            description 'Is winter cool or cool?'
          end
          Pry.commands.add_command CoolWinter

          CoolWinter.options[:listing].should == '/.*winter/'

          Pry.commands.delete /.*winter/
        end
      end
    end

  end

  describe "commands can save state" do
    before do
      @set = Pry::CommandSet.new do
        create_command "litella", "desc" do
          def process
            state.my_state ||= 0
            state.my_state += 1
          end
        end

        create_command "sanders", "desc" do
          def process
            state.my_state = "wood"
          end
        end

        create_command /[Hh]ello-world/, "desc" do
          def process
            state.my_state ||= 0
            state.my_state += 2
          end
        end

      end.import Pry::Commands

      @t = pry_tester(:commands => @set)
    end

    it 'should save state for the command on the Pry#command_state hash' do
      @t.eval 'litella'
      @t.pry.command_state["litella"].my_state.should == 1
    end

    it 'should ensure state is maintained between multiple invocations of command' do
      @t.eval 'litella'
      @t.eval 'litella'
      @t.pry.command_state["litella"].my_state.should == 2
    end

    it 'should ensure state with same name stored seperately for each command' do
      @t.eval 'litella', 'sanders'

      @t.pry.command_state["litella"].my_state.should == 1
      @t.pry.command_state["sanders"].my_state.should =="wood"
    end

    it 'should ensure state is properly saved for regex commands' do
      @t.eval 'hello-world', 'Hello-world'
      @t.pry.command_state[/[Hh]ello-world/].my_state.should == 4
    end
  end

  if defined?(Bond)
    describe 'complete' do
      it 'should return the arguments that are defined' do
        @set.create_command "torrid" do
          def options(opt)
            opt.on :test
            opt.on :lest
            opt.on :pests
          end
        end

        @set.complete('torrid ').should.include('--test ')
      end
    end
  end

  describe 'group' do
    before do
      @set.import(
                  Pry::CommandSet.new do
                    create_command("magic") { group("Not for a public use") }
                  end
                 )
    end

    it 'should be correct for default commands' do
      @set.commands["help"].group.should == "Help"
    end

    it 'should not change once it is initialized' do
      @set.commands["magic"].group("-==CD COMMAND==-")
      @set.commands["magic"].group.should == "Not for a public use"
    end

    it 'should not disappear after the call without parameters' do
      @set.commands["magic"].group
      @set.commands["magic"].group.should == "Not for a public use"
    end
  end
end
