# frozen_string_literal: true

describe "Pry.config.unrescued_exceptions" do
  before do
    @str_output = StringIO.new
  end

  it 'should rescue all exceptions NOT specified on unrescued_exceptions' do
    expect(Pry.config.unrescued_exceptions.include?(NameError)).to eq false
    expect do
      Pry.start(self, input: StringIO.new("raise NameError\nexit"), output: @str_output)
    end.not_to raise_error
  end

  it 'should NOT rescue exceptions specified on unrescued_exceptions' do
    old_allowlist = Pry.config.unrescued_exceptions
    Pry.config.unrescued_exceptions = [NameError]
    expect do
      Pry.start(self, input: StringIO.new("raise NameError"), output: @str_output)
    end.to raise_error NameError
    Pry.config.unrescued_exceptions = old_allowlist
  end
end
