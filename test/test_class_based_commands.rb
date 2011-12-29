require 'helper'

# integration tests
describe "integration tests for class-based commands" do
  before do
    @set = Pry::CommandSet.new
  end

  it 'should invoke a class-based command from the REPL' do
    c = Class.new(Pry::CommandContext) do
      def call
        output.puts "yippee!"
      end
    end

    @set.command 'foo', "desc", :definition => c.new
    @set.import_from Pry::Commands, "exit-all"

    redirect_pry_io(InputTester.new("foo", "exit-all"), out =StringIO.new) do
      Pry.start binding, :commands => @set
    end

    out.string.should =~ /yippee!/
  end

  it 'should return specified value with :keep_retval => true' do
    c = Class.new(Pry::CommandContext) do
      def call
        :i_enjoyed_the_song_new_flame_by_simply_red_as_a_child_wandering_around_supermarkets
      end
    end

    @set.command 'foo', "desc", :keep_retval => true, :definition => c.new
    @set.import_from Pry::Commands, "exit-all"

    redirect_pry_io(InputTester.new("foo", "exit-all"), out =StringIO.new) do
      Pry.start binding, :commands => @set
    end

    out.string.should =~ /i_enjoyed_the_song_new_flame_by_simply_red_as_a_child_wandering_around_supermarkets/
  end

  it 'should NOT return specified value with :keep_retval => false' do
    c = Class.new(Pry::CommandContext) do
      def call
        :i_enjoyed_the_song_new_flame_by_simply_red_as_a_child_wandering_around_supermarkets
      end
    end

    @set.command 'foo', "desc", :keep_retval => false, :definition => c.new
    @set.import_from Pry::Commands, "exit-all"

    redirect_pry_io(InputTester.new("foo", "exit-all"), out =StringIO.new) do
      Pry.start binding, :commands => @set
    end

    out.string.should !~ /i_enjoyed_the_song_new_flame_by_simply_red_as_a_child_wandering_around_supermarkets/
  end


end
