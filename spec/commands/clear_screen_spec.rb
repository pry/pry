# frozen_string_literal: true

RSpec.describe "clear-screen" do
  before do
    @t = pry_tester
  end

  it 'calls the "clear" command on non-Windows platforms' do
    expect(Pry::Helpers::Platform).to receive(:windows?)
      .at_least(:once).and_return(false)
    expect(Pry.config.system).to receive(:call)
      .with(an_instance_of(Pry::Output), 'clear', an_instance_of(Pry))
    @t.process_command 'clear-screen'
  end

  it 'calls the "cls" command on Windows' do
    expect(Pry::Helpers::Platform).to receive(:windows?)
      .at_least(:once).and_return(true)
    expect(Pry.config.system).to receive(:call)
      .with(an_instance_of(Pry::Output), 'cls', an_instance_of(Pry))
    @t.process_command 'clear-screen'
  end
end
