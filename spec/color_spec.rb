require "helper"
RSpec.describe Pry::Color do
  it "raises an UnknownBrushError" do
    expect {
      described_class.paint "foo", :no_color
    }.to raise_error(Pry::Color::UnknownBrushError)
  end
end
