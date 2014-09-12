require_relative '../../helper'

describe Pry::Command::Cat::FileFormatter do
  describe "#file_and_line" do
    before do
      @p   = Pry.new
      @opt = Slop.new
      expect(Pry::Code).to receive(:from_file)
    end

    describe "windows filesystem" do
      it "should parse '/'style absolute path without line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("C:/Ruby193/pry_instance.rb")
        expect(line_num).to eq(nil)
      end

      it "should parse '/'style absolute path with line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("C:/Ruby193/pry_instance.rb")
        expect(line_num).to eq(2)
      end

      it "should parse '\\'style absolute path without line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("C:\\Ruby193\\pry_instance.rb")
        expect(line_num).to eq(nil)
      end

      it "should parse '\\'style absolute path with line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("C:\\Ruby193\\pry_instance.rb")
        expect(line_num).to eq(2)
      end
    end

    describe "UNIX-like filesystem" do
      it "should parse absolute path without line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("/Ruby193/pry_instance.rb")
        expect(line_num).to eq(nil)
      end

      it "should parse absolute path with line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        expect(file_name).to eq("/Ruby193/pry_instance.rb")
        expect(line_num).to eq(2)
      end
    end

    it "should parse relative path without line_num" do
      file_with_embedded_line = "pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      expect(file_name).to eq("pry_instance.rb")
      expect(line_num).to eq(nil)
    end

    it "should parse relative path with line_num" do
      file_with_embedded_line = "pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      expect(file_name).to eq("pry_instance.rb")
      expect(line_num).to eq(2)
    end
  end
end
