describe "wtf?!" do
  let(:tester) do
    pry_tester do
      def last_exception=(ex)
        @pry.last_exception = ex
      end

      def last_exception
        @pry.last_exception
      end
    end
  end

  it "unwinds nested exceptions" do
    if Gem::Version.new(RUBY_VERSION) <= Gem::Version.new('2.0.0')
      skip('Exception#cause is not supported')
    end

    begin
      begin
        begin
          raise 'inner'
        rescue RuntimeError
          raise 'outer'
        end
      end
    rescue RuntimeError => ex
      tester.last_exception = ex
    end

    expect(tester.eval('wtf -v')).to match(/
      Exception:\sRuntimeError:\souter
      .+
      Caused\sby:\sRuntimeError:\sinner
    /xm)
  end
end
