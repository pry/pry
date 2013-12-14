require 'helper'

describe "cat/file_formatter" do
  before do
    @p = Pry.new
    @opt = Slop.new
    Pry::Code.stubs(:from_file)
  end

  after do
    Pry::Code.unstub(:from_file)
  end

  describe "parse file path" do
    it 'should parse windows style(/) absolute path without line_num' do
      file_with_embedded_line = "C:/Ruby193/pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "C:/Ruby193/pry_instance.rb"
      line_num.should == nil
    end

    it 'should parse windows style(/) absolute path with line_num' do
      file_with_embedded_line = "C:/Ruby193/pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "C:/Ruby193/pry_instance.rb"
      line_num.should == 2
    end

    it 'should parse windows style(\\) absolute path without line_num' do
      file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "C:\\Ruby193\\pry_instance.rb"
      line_num.should == nil
    end

    it 'should parse windows style(\\) absolute path with line_num' do
      file_with_embedded_line = "C:\\Ruby193\\pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "C:\\Ruby193\\pry_instance.rb"
      line_num.should == 2
    end

    it 'should parse UNIX-like absolute path without line_num' do
      file_with_embedded_line = "/Ruby193/pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "/Ruby193/pry_instance.rb"
      line_num.should == nil
    end

    it 'should parse UNIX-like absolute path with line_num' do
      file_with_embedded_line = "/Ruby193/pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "/Ruby193/pry_instance.rb"
      line_num.should == 2
    end

    it 'should parse relative path without line_num' do
      file_with_embedded_line = "pry_instance.rb"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "pry_instance.rb"
      line_num.should == nil
    end

    it 'should parse relative path with line_num' do
      file_with_embedded_line = "pry_instance.rb:2"
      ff = Pry::Command::Cat::FileFormatter.new(file_with_embedded_line, @p, @opt)
      file_name, line_num = ff.file_and_line
      file_name.should == "pry_instance.rb"
      line_num.should == 2
    end
  end
end
