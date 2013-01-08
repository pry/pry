require 'helper'

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

  if defined?(BasicObject)
    it 'should work in BasicObjects' do
      cor = Class.new(BasicObject) do
        def blimey!
          ::Kernel.binding # omnom
        end
      end.new.blimey!

      pry_eval(cor, 'whereami').should =~ /::Kernel.binding [#] omnom/
    end
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

  it 'should display a description and and error if reading the file goes wrong' do
    class Cor
      def blimey!
        eval <<-END, binding, "not.found.file.erb", 7
          Pad.tester = pry_tester(binding)
          Pad.tester.eval('whereami')
        END
      end
    end

    proc { Cor.new.blimey! }.should.raise(MethodSource::SourceNotFoundError)
    Pad.tester.last_output.should =~
      /From: not.found.file.erb @ line 7 Cor#blimey!:/
    Object.remove_const(:Cor)
  end

  it 'should show code window (not just method source) if parameter passed to whereami' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami 3').should =~ /class Cor/
      end
    end
    Cor.new.blimey!
    Object.remove_const(:Cor)
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
    Object.remove_const(:Cor)
  end

  it 'should use Pry.config.default_window_size for window size when outside a method context' do
    old_size, Pry.config.default_window_size = Pry.config.default_window_size, 1
    :litella
    :pig
    out = pry_eval(binding, 'whereami')
    :punk
    :sanders

    out.should.not =~ /:litella/
    out.should =~ /:pig/
    out.should =~ /:punk/
    out.should.not =~ /:sanders/

    Pry.config.default_window_size = old_size
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
