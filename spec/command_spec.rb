describe "Pry::Command" do
  before do
    @set = Pry::CommandSet.new
    @set.import Pry::Commands
  end

  describe 'call_safely' do
    it 'should display a message if gems are missing' do
      cmd = @set.create_command "ford-prefect", "From a planet near Beetlegeuse", requires_gem: %w(ghijkl) do
        #
      end

      expect(mock_command(cmd, %w(hello world)).output).to match(/install-command ford-prefect/)
    end

    it 'should abort early if arguments are required' do
      cmd = @set.create_command 'arthur-dent', "Doesn't understand Thursdays", argument_required: true do
        #
      end

      expect { mock_command(cmd, %w()) }.to raise_error Pry::CommandError
    end

    it 'should return VOID without keep_retval' do
      cmd = @set.create_command 'zaphod-beeblebrox', "Likes pan-Galactic Gargle Blasters" do
        def process
          3
        end
      end

      expect(mock_command(cmd).return).to eq Pry::Command::VOID_VALUE
    end

    it 'should return the return value with keep_retval' do
      cmd = @set.create_command 'tricia-mcmillian', "a.k.a Trillian", keep_retval: true do
        def process
          5
        end
      end

      expect(mock_command(cmd).return).to eq 5
    end

    context "hooks API" do
      before do
        @set.create_command 'jamaica', 'Out of Many, One People' do
          def process
            output.puts 1 + args[0].to_i
          end
        end
      end

      let(:hooks) do
        h = Pry::Hooks.new
        h.add_hook('before_jamaica', 'name1') do |i|
          output.puts 3 - i.to_i
        end

        h.add_hook('before_jamaica', 'name2') do |i|
          output.puts 4 - i.to_i
        end

        h.add_hook('after_jamaica', 'name3') do |i|
          output.puts 2 + i.to_i
        end

        h.add_hook('after_jamaica', 'name4') do |i|
          output.puts 3 + i.to_i
        end
      end

      it "should call hooks in the right order" do
        out = pry_tester(hooks: hooks, commands: @set).process_command('jamaica 2')
        expect(out).to eq("1\n2\n3\n4\n5\n")
      end
    end
  end

  describe 'help' do
    it 'should default to the description for blocky commands' do
      @set.command 'oolon-colluphid', "Raving Atheist" do
        #
      end

      expect(mock_command(@set['help'], %w(oolon-colluphid), command_set: @set).output).to match(/Raving Atheist/)
    end

    it 'should use slop to generate the help for classy commands' do
      @set.create_command 'eddie', "The ship-board computer" do
        def options(opt)
          opt.banner "Over-cheerful, and makes a ticking noise."
        end
      end

      expect(mock_command(@set['help'], %w(eddie), command_set: @set).output).to match(/Over-cheerful/)
    end

    it 'should provide --help for classy commands' do
      cmd = @set.create_command 'agrajag', "Killed many times by Arthur" do
        def options(opt)
          opt.on :r, :retaliate, "Try to get Arthur back"
        end
      end

      expect(mock_command(cmd, %w(--help)).output).to match(/--retaliate/)
    end

    it 'should provide a -h for classy commands' do
      cmd = @set.create_command 'zarniwoop', "On an intergalactic cruise, in his office." do
        def options(opt)
          opt.on :e, :escape, "Help zaphod escape the Total Perspective Vortex"
        end
      end

      expect(mock_command(cmd, %w(--help)).output).to match(/Total Perspective Vortex/)
    end

    it 'should use the banner provided' do
      cmd = @set.create_command 'deep-thought', "The second-best computer ever" do
        banner <<-BANNER
          Who's merest operational parameters, I am not worthy to compute.
        BANNER
      end

      expect(mock_command(cmd, %w(--help)).output).to match(/Who\'s merest/)
    end
  end

  describe 'context' do
    let(:context) do
      {
        target: binding,
        output: StringIO.new,
        eval_string: "eval-string",
        command_set: @set,
        pry_instance: Pry.new
      }
    end

    describe '#setup' do
      it 'should capture lots of stuff from the hash passed to new before setup' do
        inside = inner_scope do |probe|
          cmd = @set.create_command('fenchurch', "Floats slightly off the ground") do
            define_method(:setup, &probe)
          end

          cmd.new(context).call
        end

        expect(inside.context).to eq(context)
        expect(inside.target).to eq(context[:target])
        expect(inside.target_self).to eq(context[:target].eval('self'))
        expect(inside.output).to eq(context[:output])
      end
    end

    describe '#process' do
      it 'should capture lots of stuff from the hash passed to new before setup' do
        inside = inner_scope do |probe|
          cmd = @set.create_command('fenchurch', "Floats slightly off the ground") do
            define_method(:process, &probe)
          end

          cmd.new(context).call
        end

        expect(inside.eval_string).to eq("eval-string")
        expect(inside.__send__(:command_set)).to eq(@set)
        expect(inside._pry_).to eq(context[:pry_instance])
      end
    end
  end

  describe 'classy api' do
    it 'should call setup, then subcommands, then options, then process' do
      cmd = @set.create_command 'rooster', "Has a tasty towel" do
        def setup
          output.puts "setup"
        end

        def subcommands(_cmd)
          output.puts "subcommands"
        end

        def options(_opt)
          output.puts "options"
        end

        def process
          output.puts "process"
        end
      end

      expect(mock_command(cmd).output).to eq "setup\nsubcommands\noptions\nprocess\n"
    end

    it 'should raise a command error if process is not overridden' do
      cmd = @set.create_command 'jeltz', "Commander of a Vogon constructor fleet" do
        def proccces
          #
        end
      end

      expect { mock_command(cmd) }.to raise_error Pry::CommandError
    end

    it 'should work if neither options, nor setup is overridden' do
      cmd = @set.create_command 'wowbagger', "Immortal, insulting.", keep_retval: true do
        def process
          5
        end
      end

      expect(mock_command(cmd).return).to eq 5
    end

    it 'should provide opts and args as provided by slop' do
      cmd = @set.create_command 'lintilla', "One of 800,000,000 clones" do
        def options(opt)
          opt.on :f, :four, "A numeric four", as: Integer, optional_argument: true
        end

        def process
          output.puts args.inspect
          output.puts opts[:f]
        end
      end

      result = mock_command(cmd, %w(--four 4 four))
      expect(result.output.split).to eq ['["four"]', '4']
    end

    it 'should allow overriding options after definition' do
      cmd = @set.create_command(/number-(one|two)/, "Lieutenants of the Golgafrinchan Captain", shellwords: false) do
        command_options listing: 'number-one'
      end

      expect(cmd.command_options[:shellwords]).to eq false
      expect(cmd.command_options[:listing]).to eq 'number-one'
    end

    it "should create subcommands" do
      cmd = @set.create_command 'mum', 'Your mum' do
        def subcommands(cmd)
          cmd.command :yell
        end

        def process
          output.puts opts.fetch_command(:blahblah).inspect
          output.puts opts.fetch_command(:yell).present?
        end
      end

      result = mock_command(cmd, ['yell'])
      expect(result.output.split).to eq ['nil', 'true']
    end

    it "should create subcommand options" do
      cmd = @set.create_command 'mum', 'Your mum' do
        def subcommands(cmd)
          cmd.command :yell do
            on :p, :person
          end
        end

        def process
          output.puts args.inspect
          output.puts opts.fetch_command(:yell).present?
          output.puts opts.fetch_command(:yell).person?
        end
      end

      result = mock_command(cmd, %w|yell --person papa|)
      expect(result.output.split).to eq ['["papa"]', 'true', 'true']
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
          options baby: :pig
          match(/goat/)
          description "waaaninngggiiigygygygygy"
        end
      end

      it 'subclasses should inherit options, match and description from superclass' do
        k = Class.new(@x)
        expect(k.options).to eq @x.options
        expect(k.match).to eq @x.match
        expect(k.description).to eq @x.description
      end
    end
  end

  describe 'tokenize' do
    it 'should interpolate string with #{} in them' do
      expect do |probe|
        cmd = @set.command('random-dent', &probe)

        _foo = 5
        cmd.new(target: binding).process_line 'random-dent #{1 + 2} #{3 + _foo}'
      end.to yield_with_args('3', '8')
    end

    it 'should not fail if interpolation is not needed and target is not set' do
      expect do |probe|
        cmd = @set.command('the-book', &probe)

        cmd.new.process_line 'the-book --help'
      end.to yield_with_args('--help')
    end

    it 'should not interpolate commands with :interpolate => false' do
      expect do |probe|
        cmd = @set.command('thor', 'norse god', interpolate: false, &probe)

        cmd.new.process_line 'thor %(#{foo})'
      end.to yield_with_args('%(#{foo})')
    end

    it 'should use shell-words to split strings' do
      expect do |probe|
        cmd = @set.command('eccentrica', &probe)

        cmd.new.process_line %(eccentrica "gallumbits" 'erot''icon' 6)
      end.to yield_with_args('gallumbits', 'eroticon', '6')
    end

    it 'should split on spaces if shellwords is not used' do
      expect do |probe|
        cmd = @set.command('bugblatter-beast', 'would eat its grandmother', shellwords: false, &probe)

        cmd.new.process_line %(bugblatter-beast "of traal")
      end.to yield_with_args('"of', 'traal"')
    end

    it 'should add captures to arguments for regex commands' do
      expect do |probe|
        cmd = @set.command(/perfectly (normal)( beast)?/i, &probe)

        cmd.new.process_line %(Perfectly Normal Beast (honest!))
      end.to yield_with_args('Normal', ' Beast', '(honest!)')
    end
  end

  describe 'process_line' do
    it 'should check for command name collisions if configured' do
      old = Pry.config.collision_warning
      Pry.config.collision_warning = true

      cmd = @set.command '_frankie' do
      end

      _frankie = 'boyle'
      output = StringIO.new
      cmd.new(target: binding, output: output).process_line %(_frankie mouse)

      expect(output.string).to match(/command .* conflicts/)

      Pry.config.collision_warning = old
    end

    it 'should spot collision warnings on assignment if configured' do
      old = Pry.config.collision_warning
      Pry.config.collision_warning = true

      cmd = @set.command 'frankie' do
      end

      output = StringIO.new
      cmd.new(target: binding, output: output).process_line %(frankie = mouse)

      expect(output.string).to match(/command .* conflicts/)

      Pry.config.collision_warning = old
    end

    it "should set the commands' arg_string and captures" do
      inside = inner_scope do |probe|
        cmd = @set.command(/benj(ie|ei)/, &probe)

        cmd.new.process_line %(benjie mouse)
      end

      expect(inside.arg_string).to eq("mouse")
      expect(inside.captures).to eq(['ie'])
    end

    it "should raise an error if the line doesn't match the command" do
      cmd = @set.command 'grunthos', 'the flatulent'
      expect { cmd.new.process_line %(grumpos) }.to raise_error Pry::CommandError
    end
   end

  describe "block parameters" do
    before do
      @context = Object.new
      @set.command "walking-spanish", "down the hall", takes_block: true do
        insert_variable(:@x, command_block.call, target)
      end
      @set.import Pry::Commands

      @t = pry_tester(@context, commands: @set)
    end

    it 'should accept multiline blocks' do
      @t.eval <<-EOS
        walking-spanish | do
          :jesus
        end
      EOS

      expect(@context.instance_variable_get(:@x)).to eq :jesus
    end

    it 'should accept normal parameters along with block' do
      @set.block_command "walking-spanish",
          "litella's been screeching for a blind pig.",
          takes_block: true do |x, y|
        insert_variable(:@x, x, target)
        insert_variable(:@y, y, target)
        insert_variable(:@block_var, command_block.call, target)
      end

      @t.eval 'walking-spanish john carl| { :jesus }'

      expect(@context.instance_variable_get(:@x)).to eq "john"
      expect(@context.instance_variable_get(:@y)).to eq "carl"
      expect(@context.instance_variable_get(:@block_var)).to eq :jesus
    end

    describe "single line blocks" do
      it 'should accept blocks with do ; end' do
        @t.eval 'walking-spanish | do ; :jesus; end'
        expect(@context.instance_variable_get(:@x)).to eq :jesus
      end

      it 'should accept blocks with do; end' do
        @t.eval 'walking-spanish | do; :jesus; end'
        expect(@context.instance_variable_get(:@x)).to eq :jesus
      end

      it 'should accept blocks with { }' do
        @t.eval 'walking-spanish | { :jesus }'
        expect(@context.instance_variable_get(:@x)).to eq :jesus
      end
    end

    describe "block-related content removed from arguments" do
      describe "arg_string" do
        it 'should remove block-related content from arg_string (with one normal arg)' do
          @set.block_command "walking-spanish", "down the hall", takes_block: true do |x, _y|
            insert_variable(:@arg_string, arg_string, target)
            insert_variable(:@x, x, target)
          end

          @t.eval 'walking-spanish john| { :jesus }'

          expect(@context.instance_variable_get(:@arg_string)).to eq @context.instance_variable_get(:@x)
        end

        it 'should remove block-related content from arg_string (with no normal args)' do
          @set.block_command "walking-spanish", "down the hall", takes_block: true do
            insert_variable(:@arg_string, arg_string, target)
          end

          @t.eval 'walking-spanish | { :jesus }'

          expect(@context.instance_variable_get(:@arg_string)).to eq ""
        end

        it 'should NOT remove block-related content from arg_string when :takes_block => false' do
          block_string = "| { :jesus }"
          @set.block_command "walking-spanish", "homemade special", takes_block: false do
            insert_variable(:@arg_string, arg_string, target)
          end

          @t.eval "walking-spanish #{block_string}"

          expect(@context.instance_variable_get(:@arg_string)).to eq block_string
        end
      end

      describe "args" do
        describe "block_command" do
          it "should remove block-related content from arguments" do
            @set.block_command "walking-spanish", "glass is full of sand", takes_block: true do |x, y|
              insert_variable(:@x, x, target)
              insert_variable(:@y, y, target)
            end

            @t.eval 'walking-spanish | { :jesus }'

            expect(@context.instance_variable_get(:@x)).to eq nil
            expect(@context.instance_variable_get(:@y)).to eq nil
          end

          it "should NOT remove block-related content from arguments if :takes_block => false" do
            @set.block_command "walking-spanish", "litella screeching for a blind pig", takes_block: false do |x, y|
              insert_variable(:@x, x, target)
              insert_variable(:@y, y, target)
            end

            @t.eval 'walking-spanish | { :jesus }'

            expect(@context.instance_variable_get(:@x)).to eq "|"
            expect(@context.instance_variable_get(:@y)).to eq "{"
          end
        end

        describe "create_command" do
          it "should remove block-related content from arguments" do
            @set.create_command "walking-spanish", "punk sanders carved one out of wood", takes_block: true do
              def process(x, y)
                insert_variable(:@x, x, target)
                insert_variable(:@y, y, target)
              end
            end

            @t.eval 'walking-spanish | { :jesus }'

            expect(@context.instance_variable_get(:@x)).to eq nil
            expect(@context.instance_variable_get(:@y)).to eq nil
          end

          it "should NOT remove block-related content from arguments if :takes_block => false" do
            @set.create_command "walking-spanish", "down the hall", takes_block: false do
              def process(x, y)
                insert_variable(:@x, x, target)
                insert_variable(:@y, y, target)
              end
            end

            @t.eval 'walking-spanish | { :jesus }'

            expect(@context.instance_variable_get(:@x)).to eq "|"
            expect(@context.instance_variable_get(:@y)).to eq "{"
          end
        end
      end
    end

    describe "blocks can take parameters" do
      describe "{} style blocks" do
        it 'should accept multiple parameters' do
          @set.block_command "walking-spanish", "down the hall", takes_block: true do
            insert_variable(:@x, command_block.call(1, 2), target)
          end

          @t.eval 'walking-spanish | { |x, y| [x, y] }'

          expect(@context.instance_variable_get(:@x)).to eq [1, 2]
        end
      end

      describe "do/end style blocks" do
        it 'should accept multiple parameters' do
          @set.create_command "walking-spanish", "litella", takes_block: true do
            def process
              insert_variable(:@x, command_block.call(1, 2), target)
            end
          end

          @t.eval <<-EOS
            walking-spanish | do |x, y|
              [x, y]
            end
          EOS

          expect(@context.instance_variable_get(:@x)).to eq [1, 2]
        end
      end
    end

    describe "closure behaviour" do
      it 'should close over locals in the definition context' do
        @t.eval 'var = :hello', 'walking-spanish | { var }'
        expect(@context.instance_variable_get(:@x)).to eq :hello
      end
    end

    describe "exposing block parameter" do
      describe "block_command" do
        it "should expose block in command_block method" do
          @set.block_command "walking-spanish", "glass full of sand", takes_block: true do
            insert_variable(:@x, command_block.call, target)
          end

          @t.eval 'walking-spanish | { :jesus }'

          expect(@context.instance_variable_get(:@x)).to eq :jesus
        end
      end

      describe "create_command" do
        it "should NOT expose &block in create_command's process method" do
          @set.create_command "walking-spanish", "down the hall", takes_block: true do
            def process(&block)
              block.call
            end
          end
          @out = StringIO.new

          expect { @t.eval 'walking-spanish | { :jesus }' }.to raise_error(NoMethodError)
        end

        it "should expose block in command_block method" do
          @set.create_command "walking-spanish", "homemade special", takes_block: true do
            def process
              insert_variable(:@x, command_block.call, target)
            end
          end

          @t.eval 'walking-spanish | { :jesus }'

          expect(@context.instance_variable_get(:@x)).to eq :jesus
        end
      end
    end
  end

  describe "a command made with a custom sub-class" do
    before do
      class MyTestCommand < Pry::ClassCommand
        match(/my-*test/)
        description 'So just how many sound technicians does it take to' \
          'change a lightbulb? 1? 2? 3? 1-2-3? Testing?'
        options shellwords: false, listing: 'my-test'

        undef process if method_defined? :process

        def process
          output.puts command_name * 2
        end
      end

      Pry.config.commands.add_command MyTestCommand
    end

    after do
      Pry.config.commands.delete 'my-test'
    end

    it "allows creation of custom subclasses of Pry::Command" do
      expect(pry_eval('my---test')).to match(/my-testmy-test/)
    end

    it "shows the source of the process method" do
      expect(pry_eval('show-source my-test')).to match(/output.puts command_name/)
    end

    describe "command options hash" do
      it "is always present" do
        options_hash = {
          requires_gem: [],
          keep_retval: false,
          argument_required: false,
          interpolate: true,
          shellwords: false,
          listing: 'my-test',
          use_prefix: true,
          takes_block: false
        }
        expect(MyTestCommand.options).to eq options_hash
      end

      describe ":listing option" do
        it "defaults to :match if not set explicitly" do
          class HappyNewYear < Pry::ClassCommand
            match 'happy-new-year'
            description 'Happy New Year 2013'
          end
          Pry.config.commands.add_command HappyNewYear

          expect(HappyNewYear.options[:listing]).to eq 'happy-new-year'

          Pry.config.commands.delete 'happy-new-year'
        end

        it "can be set explicitly" do
          class MerryChristmas < Pry::ClassCommand
            match 'merry-christmas'
            description 'Merry Christmas!'
            command_options listing: 'happy-holidays'
          end
          Pry.config.commands.add_command MerryChristmas

          expect(MerryChristmas.options[:listing]).to eq 'happy-holidays'

          Pry.config.commands.delete 'merry-christmas'
        end

        it "equals to :match option's inspect, if :match is Regexp" do
          class CoolWinter < Pry::ClassCommand
            match(/.*winter/)
            description 'Is winter cool or cool?'
          end
          Pry.config.commands.add_command CoolWinter

          expect(CoolWinter.options[:listing]).to eq '/.*winter/'

          Pry.config.commands.delete(/.*winter/)
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

        create_command(/[Hh]ello-world/, "desc") do
          def process
            state.my_state ||= 0
            state.my_state += 2
          end
        end
      end.import Pry::Commands

      @t = pry_tester(commands: @set)
    end

    it 'should save state for the command on the Pry#command_state hash' do
      @t.eval 'litella'
      expect(@t.pry.command_state["litella"].my_state).to eq 1
    end

    it 'should ensure state is maintained between multiple invocations of command' do
      @t.eval 'litella'
      @t.eval 'litella'
      expect(@t.pry.command_state["litella"].my_state).to eq 2
    end

    it 'should ensure state with same name stored seperately for each command' do
      @t.eval 'litella', 'sanders'

      expect(@t.pry.command_state["litella"].my_state).to eq 1
      expect(@t.pry.command_state["sanders"].my_state).to eq("wood")
    end

    it 'should ensure state is properly saved for regex commands' do
      @t.eval 'hello-world', 'Hello-world'
      expect(@t.pry.command_state[/[Hh]ello-world/].my_state).to eq 4
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

        expect(@set.complete('torrid ')).to.include('--test ')
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
      expect(@set["help"].group).to eq "Help"
    end

    it 'should not change once it is initialized' do
      @set["magic"].group("-==CD COMMAND==-")
      expect(@set["magic"].group).to eq "Not for a public use"
    end

    it 'should not disappear after the call without parameters' do
      @set["magic"].group
      expect(@set["magic"].group).to eq "Not for a public use"
    end
  end
end
