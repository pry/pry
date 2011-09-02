require 'helper'

describe "Pry::DefaultCommands::Shell" do
  describe "cat" do

    # this doesnt work so well on rbx due to differences in backtrace
    # so we currently skip rbx until we figure out a workaround
    if !rbx?
      it 'cat --ex should give warning when exception is raised in repl' do
        mock_pry("this raises error", "cat --ex").should =~ /Cannot cat exceptions raised in REPL/
      end

      it 'cat --ex should correctly display code that generated exception' do
        mock_pry("broken_method", "cat --ex").should =~ /this method is broken/
      end
    end
  end
end
