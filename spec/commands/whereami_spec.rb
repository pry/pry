require_relative '../helper'

describe "whereami" do
  it 'should work with methods that have been undefined' do
    class Cor
      def blimey!
        Cor.send :undef_method, :blimey!
        Pad.binding = binding
      end
    end

    Cor.new.blimey!

    # using [.] so the regex doesn't match itself
    pry_eval(Pad.binding, 'whereami').should =~ /self[.]blimey!/

    Object.remove_const(:Cor)
  end

  it 'should work in objects with no method methods' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami').should =~ /Cor[#]blimey!/
      end

      def method; "moo"; end
    end
    Cor.new.blimey!
    Object.remove_const(:Cor)
  end

  it 'should properly set _file_, _line_ and _dir_' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami', '_file_').
          should == File.expand_path(__FILE__)
      end
    end

    Cor.new.blimey!
    Object.remove_const(:Cor)
  end

  it 'should work in BasicObjects' do
    cor = Class.new(BasicObject) do
      def blimey!
        ::Kernel.binding # omnom
      end
    end.new.blimey!

    pry_eval(cor, 'whereami').should =~ /::Kernel.binding [#] omnom/
  end

  it 'should show description and correct code when __LINE__ and __FILE__ are outside @method.source_location' do
    class Cor
      def blimey!
        eval <<-END, binding, "spec/fixtures/example.erb", 1
          pry_eval(binding, 'whereami')
        END
      end
    end

    Cor.instance_method(:blimey!).source.should =~ /pry_eval/
    Cor.new.blimey!.should =~ /Cor#blimey!.*Look at me/m
    Object.remove_const(:Cor)
  end

  it 'should show description and correct code when @method.source_location would raise an error' do
    class Cor
      eval <<-END, binding, "spec/fixtures/example.erb", 1
        def blimey!
          pry_eval(binding, 'whereami')
        end
        END
      end

      lambda{
        Cor.instance_method(:blimey!).source
      }.should.raise(MethodSource::SourceNotFoundError)

      Cor.new.blimey!.should =~ /Cor#blimey!.*Look at me/m
      Object.remove_const(:Cor)
    end

    # Now that we use stagger_output (paging output) we no longer get
    # the "From: " line, as we output everything in one go (not separate output.puts)
    # and so the user just gets a single `Error: Cannot open
    # "not.found.file.erb" for reading.`
    # which is good enough IMO. Unfortunately we can't test for it
    # though, as we don't hook stdout.
    #
    # it 'should display a description and error if reading the file goes wrong' do
    #   class Cor
    #     def blimey!
    #       eval <<-END, binding, "not.found.file.erb", 7
    #         Pad.tester = pry_tester(binding)
    #         Pad.tester.eval('whereami')
    #       END
    #     end
    #   end

    #   proc { Cor.new.blimey! }.should.raise(MethodSource::SourceNotFoundError)

    #   Pad.tester.last_output.should =~
    #     /From: not.found.file.erb @ line 7 Cor#blimey!:/
    #   Object.remove_const(:Cor)
    # end

    it 'should show code window (not just method source) if parameter passed to whereami' do
      class Cor
        def blimey!
          pry_eval(binding, 'whereami 3').should =~ /class Cor/
        end
      end
      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should show entire method when -m option used' do
      old_size, Pry.config.default_window_size = Pry.config.default_window_size, 1
      old_cutoff, Pry::Command::Whereami.method_size_cutoff = Pry::Command::Whereami.method_size_cutoff, 1
      class Cor
        def blimey!
          1
          2
          pry_eval(binding, 'whereami -m').should =~ /def blimey/
        end
      end
      Pry::Command::Whereami.method_size_cutoff, Pry.config.default_window_size = old_cutoff, old_size
      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should show entire file when -f option used' do
      class Cor
        def blimey!
          1
          2
          pry_eval(binding, 'whereami -f').should =~ /show entire file when -f option used/
        end
      end
      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    describe "-c" do
      it 'should show class when -c option used, and locate correct candidate' do
        require 'fixtures/whereami_helper'
        class Cor
          def blimey!
            1
            2
            out = pry_eval(binding, 'whereami -c')
            out.should =~ /class Cor/
            out.should =~ /blimey/
          end
        end
        Cor.new.blimey!
        Object.remove_const(:Cor)
      end

      it 'should show class when -c option used, and locate correct superclass' do
        class Cor
          def blimey!
            1
            2
            out = pry_eval(binding, 'whereami -c')
            out.should =~ /class Cor/
            out.should =~ /blimey/
          end
        end

        class Horse < Cor
          def pig;end
        end

        Horse.new.blimey!
        Object.remove_const(:Cor)
        Object.remove_const(:Horse)
      end

      # https://github.com/rubinius/rubinius/pull/2247
      unless Pry::Helpers::BaseHelpers.rbx?
        it 'should show class when -c option used, and binding is outside a method' do
          class Cor
            def blimey;end

            out = pry_eval(binding, 'whereami -c')
            out.should =~ /class Cor/
            out.should =~ /blimey/
          end
          Object.remove_const(:Cor)
        end
      end
    end

  it 'should not show line numbers or marker when -n switch is used' do
    class Cor
      def blimey!
        out = pry_eval(binding, 'whereami -n')
        out.should =~ /^\s*def/
        out.should.not =~ /\=\>/
      end
    end

    Cor.new.blimey!
    Object.remove_const :Cor
  end

  it 'should use Pry.config.default_window_size for window size when outside a method context' do
    old_size, Pry.config.default_window_size = Pry.config.default_window_size, 1

    class TemporaryClass
      :litella
      :pig
      out = pry_eval(binding, 'whereami')
      :punk
      :sanders

      out.should.not =~ /:litella/
      out.should =~ /:pig/
      out.should =~ /:punk/
      out.should.not =~ /:sanders/
    end

    Pry.config.default_window_size = old_size
    Object.remove_const :TemporaryClass
  end

  it "should work at the top level" do
    pry_eval(Pry.toplevel_binding, 'whereami').should =~
      /At the top level/
  end

  it "should work inside a class" do
    pry_eval(Pry, 'whereami').should =~ /Inside Pry/
  end

  it "should work inside an object" do
    pry_eval(Object.new, 'whereami').should =~ /Inside #<Object/
  end
end
