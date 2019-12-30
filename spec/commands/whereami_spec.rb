# frozen_string_literal: true

require 'method_source'

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
    expect(pry_eval(Pad.binding, 'whereami')).to match(/self[.]blimey!/)

    Object.remove_const(:Cor)
  end

  it 'should work in objects with no method methods' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami')
      end

      def method
        "moo"
      end
    end
    expect(Cor.new.blimey!).to match(/Cor[#]blimey!/)
    Object.remove_const(:Cor)
  end

  it 'should properly set _file_, _line_ and _dir_' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami', '_file_')
      end
    end

    expect(Cor.new.blimey!).to eq File.expand_path(__FILE__)
    Object.remove_const(:Cor)
  end

  if RUBY_VERSION > "2.0.0"
    it 'should work with prepended methods' do
      module Cor2
        def blimey!
          super
        end
      end
      class Cor
        prepend Cor2
        def blimey!
          pry_eval(binding, 'whereami')
        end
      end

      expect(Cor.new.blimey!).to match(/Cor2[#]blimey!/)

      Object.remove_const(:Cor)
      Object.remove_const(:Cor2)
    end
  end

  it 'should work in BasicObjects' do
    cor = Class.new(BasicObject) do
      def blimey!
        ::Kernel.binding # omnom
      end
    end.new.blimey!

    expect(pry_eval(cor, 'whereami')).to match(/::Kernel.binding [#] omnom/)
  end

  it(
    'shows description and corrects code when __LINE__ and __FILE__ are ' \
    'outside @method.source_location'
  ) do
    class Cor
      def blimey!
        eval(<<-WHEREAMI, binding, 'spec/fixtures/example.erb', 1)
          pry_eval(binding, 'whereami')
        WHEREAMI
      end
    end

    expect(Cor.instance_method(:blimey!).source).to match(/pry_eval/)
    expect(Cor.new.blimey!).to match(/Cor#blimey!.*Look at me/m)
    Object.remove_const(:Cor)
  end

  it(
    'shows description and corrects code when @method.source_location ' \
    'would raise an error'
  ) do
    class Cor
      eval <<-WHEREAMI, binding, "spec/fixtures/example.erb", 1
        def blimey!
          pry_eval(binding, 'whereami')
        end
      WHEREAMI
    end

    expect { Cor.instance_method(:blimey!).source }
      .to raise_error MethodSource::SourceNotFoundError

    expect(Cor.new.blimey!).to match(/Cor#blimey!.*Look at me/m)
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
  #     /From: not.found.file.erb:7 Cor#blimey!/
  #   Object.remove_const(:Cor)
  # end

  it 'should show code window (not just method source) if parameter passed to whereami' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami 3')
      end
    end
    expect(Cor.new.blimey!).to match(/class Cor/)
    Object.remove_const(:Cor)
  end

  it 'should show entire method when -m option used' do
    old_size = Pry.config.default_window_size
    Pry.config.default_window_size = 1
    old_cutoff = Pry::Command::Whereami.method_size_cutoff
    Pry::Command::Whereami.method_size_cutoff = 1
    class Cor
      def blimey!
        @foo = 1
        @bar = 2
        pry_eval(binding, 'whereami -m')
      end
    end
    Pry::Command::Whereami.method_size_cutoff = old_cutoff
    Pry.config.default_window_size = old_size
    result = Cor.new.blimey!
    Object.remove_const(:Cor)
    expect(result).to match(/def blimey/)
  end

  it 'should show entire file when -f option used' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami -f')
      end
    end
    result = Cor.new.blimey!
    Object.remove_const(:Cor)
    expect(result).to match(/show entire file when -f option used/)
  end

  describe "-c" do
    it 'should show class when -c option used, and locate correct candidate' do
      require 'fixtures/whereami_helper'
      class Cor
        def blimey!
          pry_eval(binding, 'whereami -c')
        end
      end
      out = Cor.new.blimey!
      Object.remove_const(:Cor)
      expect(out).to match(/class Cor/)
      expect(out).to match(/blimey/)
    end

    it 'should show class when -c option used, and locate correct superclass' do
      class Cor
        def blimey!
          pry_eval(binding, 'whereami -c')
        end
      end

      class Horse < Cor
        def pig; end
      end

      out = Horse.new.blimey!
      Object.remove_const(:Cor)
      Object.remove_const(:Horse)

      expect(out).to match(/class Cor/)
      expect(out).to match(/blimey/)
    end

    it 'should show class when -c option used, and binding is outside a method' do
      class Cor
        extend RSpec::Matchers
        def blimey; end
        out = pry_eval(binding, 'whereami -c')
        expect(out).to match(/class Cor/)
        expect(out).to match(/blimey/)
      end
      Object.remove_const(:Cor)
    end

    it 'should show class when -c option used, and beginning of the class is on the' \
       'same line as another expression' do
      out = class Cor
              def blimey; end
              pry_eval(binding, 'whereami -c')
            end
      expect(out).to match(/class Cor/)
      expect(out).to match(/blimey/)
      Object.remove_const(:Cor)
    end
  end

  it 'should not show line numbers or marker when -n switch is used' do
    class Cor
      def blimey!
        pry_eval(binding, 'whereami -n')
      end
    end
    out = Cor.new.blimey!
    expect(out).to match(/^\s*def/)
    expect(out).to_not match(/\=\>/)
    Object.remove_const(:Cor)
  end

  it(
    'uses Pry.config.default_window_size for window size when outside a method context'
  ) do
    old_size = Pry.config.default_window_size
    Pry.config.default_window_size = 1
    _foo = :litella
    _foo = :pig
    out = pry_eval(binding, 'whereami')
    _foo = :punk
    _foo = :sanders

    expect(out).not_to match(/:litella/)
    expect(out).to match(/:pig/)
    expect(out).to match(/:punk/)
    expect(out).not_to match(/:sanders/)

    Pry.config.default_window_size = old_size
  end

  it "should work at the top level" do
    expect(pry_eval(Pry.toplevel_binding, 'whereami')).to match(
      /At the top level/
    )
  end

  it "should work inside a class" do
    expect(pry_eval(Pry, 'whereami')).to match(/Inside Pry/)
  end

  it "should work inside an object" do
    expect(pry_eval(Object.new, 'whereami')).to match(/Inside #<Object/)
  end
end
