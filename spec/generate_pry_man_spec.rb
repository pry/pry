require File.expand_path(File.dirname(__FILE__) + "../../man/generate_pry_man/generate_pry_man.rb")
require 'tempfile'

describe GeneratePryMan do
  before  do
    @tmp_html=Tempfile.new('man-html')
    @tmp_roff=Tempfile.new('man-roff')
    @tmp_ronn=Tempfile.new('man-ronn')
    @man_sections = { :authors      => "Fred Flintstone",
      :description  => "Does stuff.",
      :examples     => "Look at me do stuff.",
      :files        => "Here are some places to look on your system",
      :homepage     => "Here are some places to look on the intrawebz",
      :options      => "Here are some of my cool options",
      :pry_commands => "Some commands."}

    @gpm = GeneratePryMan.new({ :man_sections => @man_sections,
                                :ronn_file    => @tmp_ronn,
                                :html_file    => @tmp_html,
                                :roff_file    => @tmp_roff })
  end

  unless Pry::Helpers::BaseHelpers.jruby?
    it "generates a proper man-page roff file" do
      test_roff = File.read(File.expand_path(File.dirname(__FILE__) + "../../man/generate_pry_man/ext/test.roff"))
      test_roff.gsub!('MONTH AND YEAR',Date.today.strftime('%B %Y'))
      @gpm.ronn_to_roff
      File.read(@tmp_roff.path).should == test_roff
    end

    it "generates a proper man-page html file" do
      test_html = File.read(File.expand_path(File.dirname(__FILE__) + "../../man/generate_pry_man/ext/test.html"))
      test_html.gsub!('MONTH AND YEAR',Date.today.strftime('%B %Y'))
      @gpm.ronn_to_html
      File.read(@tmp_html.path).should == test_html
    end
  end
end
