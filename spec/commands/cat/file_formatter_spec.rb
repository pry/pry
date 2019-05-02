# frozen_string_literal: true

describe Pry::Command::Cat::FileFormatter do
  before do
    @p   = Pry.new
    @opt = Pry::Slop.new
  end

  describe "#file_and_line" do
    before do
      expect(Pry::Code).to receive(:from_file)
    end

    describe "windows filesystem" do
      it "parses '/'style absolute path without line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "C:/Ruby193/pry_instance.rb"
        expect(line_num).to eq nil
      end

      it "parses '/'style absolute path with line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb:2"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "C:/Ruby193/pry_instance.rb"
        expect(line_num).to eq 2
      end

      it "parses '\\'style absolute path without line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "C:\\Ruby193\\pry_instance.rb"
        expect(line_num).to eq nil
      end

      it "parses '\\'style absolute path with line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb:2"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "C:\\Ruby193\\pry_instance.rb"
        expect(line_num).to eq 2
      end
    end

    describe "UNIX-like filesystem" do
      it "parses absolute path without line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "/Ruby193/pry_instance.rb"
        expect(line_num).to eq nil
      end

      it "parses absolute path with line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb:2"
        ff = described_class.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq "/Ruby193/pry_instance.rb"
        expect(line_num).to eq 2
      end
    end

    it "parses relative path without line_num" do
      file_with_embedded_line = "pry_instance.rb"
      ff = described_class.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      expect(file_name).to eq "pry_instance.rb"
      expect(line_num).to eq nil
    end

    it "parses relative path with line_num" do
      file_with_embedded_line = "pry_instance.rb:2"
      ff = described_class.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      expect(file_name).to eq "pry_instance.rb"
      expect(line_num).to eq 2
    end
  end

  describe "#format" do
    it "formats given files" do
      ff = described_class.new(__FILE__, @p, @opt)
      expect(ff.format).to match(/it "formats given files" do/)
    end

    it "formats given files with line number" do
      ff = described_class.new(__FILE__ + ':83', @p, @opt)
      expect(ff.format).to match(/it "formats given files" do/)
    end
  end
end
