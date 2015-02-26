require_relative '../../helper'

describe Pry::Command::Cat::FileFormatter do
  before do
    @p   = Pry.new
    @opt = Slop.new
  end

  describe "#file_and_line" do
    before do
      expect(Pry::Code).to receive(:from_file)
    end

    describe "windows filesystem" do
      it "should parse '/'style absolute path without line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "C:/Ruby193/pry_instance.rb"
        line_num.should eq nil
      end

      it "should parse '/'style absolute path with line_num" do
        file_with_embedded_line = "C:/Ruby193/pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "C:/Ruby193/pry_instance.rb"
        line_num.should eq 2
      end

      it "should parse '\\'style absolute path without line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "C:\\Ruby193\\pry_instance.rb"
        line_num.should eq nil
      end

      it "should parse '\\'style absolute path with line_num" do
        file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "C:\\Ruby193\\pry_instance.rb"
        line_num.should eq 2
      end
    end

    describe "UNIX-like filesystem" do
      it "should parse absolute path without line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "/Ruby193/pry_instance.rb"
        line_num.should eq nil
      end

      it "should parse absolute path with line_num" do
        file_with_embedded_line = "/Ruby193/pry_instance.rb:2"
        ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
        file_name, line_num = ff.file_and_line
        file_name.should eq "/Ruby193/pry_instance.rb"
        line_num.should eq 2
      end
    end

    it "should parse relative path without line_num" do
      file_with_embedded_line = "pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should eq "pry_instance.rb"
      line_num.should eq nil
    end

    it "should parse relative path with line_num" do
      file_with_embedded_line = "pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should eq "pry_instance.rb"
      line_num.should eq 2
    end
  end

  describe "#format" do
    it "formats given files" do
      ff = Pry::Command::Cat::FileFormatter.new(__FILE__, @p, @opt)
      expect(ff.format).to match(/it "formats given files" do/)
    end

    it "should format given files with line number" do
      ff = Pry::Command::Cat::FileFormatter.new(__FILE__ + ':83', @p, @opt)
      expect(ff.format).to match(/it "formats given files" do/)
    end
  end
end
