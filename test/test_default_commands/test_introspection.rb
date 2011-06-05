require 'helper'

describe "Pry::DefaultCommands::Introspection" do
  describe "show-method" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method -l sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /def o.sample/
      $str_output = nil
    end

    it 'should output a method\'s source if inside method without needing to use method name, and using the -l switch' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method -l", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /\d+: def o.sample/
      $str_output = nil
    end

    # dynamically defined method source retrieval is only supported in
    # 1.9 - where Method#source_location is native
    if RUBY_VERSION =~ /1.9/
      it 'should output a method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("def dyna_method", ":testing", "end", "show-method dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output a method\'s source for a method defined inside pry, even if exceptions raised before hand' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("bad code", "123", "bad code 2", "1 + 2", "def dyna_method", ":testing", "end", "show-method dyna_method"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def dyna_method/
        Object.remove_method :dyna_method
      end

      it 'should output an instance method\'s source for a method defined inside pry' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "def yo", "end", "end", "show-method A#yo"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /def yo/
        Object.remove_const :A
      end

      it 'should output an instance method\'s source for a method defined inside pry using define_method' do
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("class A", "define_method(:yup) {}", "end", "end", "show-method A#yup"), str_output) do
          TOPLEVEL_BINDING.pry
        end

        str_output.string.should =~ /define_method\(:yup\)/
        Object.remove_const :A
      end
    end
  end

  # show-command only works in implementations that support Proc#source_location
  if Proc.method_defined?(:source_location)
    describe "show-command" do
      it 'should show source for an ordinary command' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo" do
            :body_of_foo
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command foo"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo/
      end

      it 'should show source for a command with spaces in its name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command "foo bar" do
            :body_of_foo_bar
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command \"foo bar\""), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_bar/
      end

      it 'should show source for a command by listing name' do
        set = Pry::CommandSet.new do
          import_from Pry::Commands, "show-command"
          command /foo(.*)/, "", :listing => "bar" do
            :body_of_foo_regex
          end
        end
        str_output = StringIO.new
        redirect_pry_io(InputTester.new("show-command bar"), str_output) do
          Pry.new(:commands => set).rep
        end
        str_output.string.should =~ /:body_of_foo_regex/
      end
    end
  end


end
