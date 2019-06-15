# frozen_string_literal: true

describe "show-doc" do
  before do
    @obj = Object.new

    # obj docs
    def @obj.sample_method; end
  end

  it "emits a deprecation warning" do
    expect(pry_eval(binding, 'show-doc @obj.sample_method'))
      .to match(/WARNING: the show-doc command is deprecated/)
  end

  it "shows docs" do
    expect(pry_eval(binding, 'show-doc @obj.sample_method')).to match(/obj docs/)
  end
end
