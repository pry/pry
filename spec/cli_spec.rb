RSpec.describe Pry::CLI do
  before do
    Pry::CLI.reset
  end

  describe "parsing options" do
    it 'should raise if no options defined' do
      expect { Pry::CLI.parse_options(["--nothing"]) }.to raise_error Pry::CLI::NoOptionsError
    end

    it "should remove args from ARGV by default" do
      argv = ['filename', '-v']
      Pry::CLI.add_options do
        on :v, "Display the Pry version" do
          # irrelevant
        end
      end.parse_options(argv)
      expect(argv.include?('-v')).to eq false
    end

    it "forwards remaining arguments as ARGV when -- is passed as an argument" do
      argv = ['-v', '--', '--one', '-two', '3', 'four']
      described_class.add_options { on(:v, '...') {} }.parse_options(argv)
      expect(argv).to eq(%w[--one -two 3 four])
    end

    it "forwards remaining arguments as ARGV when - is passed as an argument" do
      argv = ['-v', '-', '--one', '-two', '3', 'four']
      described_class.add_options { on(:v, '...') {} }.parse_options(argv)
      expect(argv).to eq(%w[--one -two 3 four])
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

      expect(run).to eq true
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

      expect(run).to equal true
      expect(run2).to equal true
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

      expect(run).to eq true
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

      expect(run).to eq true
      expect(run2).to eq true
    end
  end
end
