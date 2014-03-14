require_relative 'helper'

describe Pry::Hooks do
  before do
    Pry::CLI.reset
  end

  describe "parsing options" do
    it 'should raise if no options defined' do
      lambda { Pry::CLI.parse_options(["--nothing"]) }.should.raise Pry::CLI::NoOptionsError
    end

    it "should remove args from ARGV by default" do
      ARGV << '-v'
      Pry::CLI.add_options do
        on :v, "Display the Pry version" do
          # irrelevant
        end
      end.parse_options
      ARGV.include?('-v').should.be_false
    end
  end

  describe "adding options" do
    it "should be able to add an option" do
      run = false

      Pry::CLI.add_options do
        on :optiontest, "A test option" do
          run = true
        end
      end.parse_options(["--optiontest"])

      run.should.be_true
    end

    it "should be able to add multiple options" do
      run = false
      run2 = false

      Pry::CLI.add_options do
        on :optiontest, "A test option" do
          run = true
        end
      end.add_options do
        on :optiontest2, "Another test option" do
          run2 = true
        end
      end.parse_options(["--optiontest", "--optiontest2"])

      run.should.be_true
      run2.should.be_true
    end

  end

  describe "processing options" do
    it "should be able to process an option" do
      run = false

      Pry::CLI.add_options do
        on :optiontest, "A test option"
      end.add_option_processor do |opts|
        run = true if opts.present?(:optiontest)
      end.parse_options(["--optiontest"])

      run.should.be_true
    end

    it "should be able to  process multiple options" do
      run = false
      run2 = false

      Pry::CLI.add_options do
        on :optiontest, "A test option"
        on :optiontest2, "Another test option"
      end.add_option_processor do |opts|
        run = true if opts.present?(:optiontest)
      end.add_option_processor do |opts|
        run2 = true if opts.present?(:optiontest2)
      end.parse_options(["--optiontest", "--optiontest2"])

      run.should.be_true
      run2.should.be_true
    end

  end
end
