# frozen_string_literal: true

describe Pry::Method::Patcher do
  # rubocop:disable Style/SingleLineMethods
  before do
    @x = Object.new
    def @x.test; :before; end
    @method = Pry::Method(@x.method(:test))
  end
  # rubocop:enable Style/SingleLineMethods

  it "should change the behaviour of the method" do
    expect(@x.test).to eq :before
    @method.redefine "def @x.test; :after; end\n"
    expect(@x.test).to eq :after
  end

  it "should return a new method with new source" do
    expect(@method.source.strip).to eq "def @x.test; :before; end"
    expect(@method.redefine("def @x.test; :after; end\n")
      .source.strip).to eq "def @x.test; :after; end"
  end

  it "should change the source of new Pry::Method objects" do
    @method.redefine "def @x.test; :after; end\n"
    expect(Pry::Method(@x.method(:test)).source.strip).to eq "def @x.test; :after; end"
  end

  it "should preserve visibility" do
    class << @x
      private :test # rubocop:disable Style/AccessModifierDeclarations
    end
    expect(@method.visibility).to eq :private
    @method.redefine "def @x.test; :after; end\n"
    expect(Pry::Method(@x.method(:test)).visibility).to eq :private
  end
end
