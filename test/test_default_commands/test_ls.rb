require 'helper'
describe "ls" do
  describe "below ceiling" do
    it "should stop before Object by default" do
      mock_pry("cd Class.new{ def goo; end }.new", "ls").should.not =~ /Object/
      mock_pry("cd Class.new{ def goo; end }", "ls -M").should.not =~ /Object/
    end

    it "should include object if -v is given" do
      mock_pry("cd Class.new{ def goo; end }.new", "ls -m -v").should =~ /Object/
      mock_pry("cd Class.new{ def goo; end }", "ls -vM").should =~ /Object/
    end

    it "should include super-classes by default" do
      mock_pry("cd Class.new(Class.new{ def goo; end }).new", "ls").should =~ /goo/
      mock_pry("cd Class.new(Class.new{ def goo; end })", "ls -M").should =~ /goo/
    end

    it "should not include super-classes when -q is given" do
      mock_pry("cd Class.new(Class.new{ def goo; end }).new", "ls -q").should.not =~ /goo/
      mock_pry("cd Class.new(Class.new{ def goo; end })", "ls -M -q").should.not =~ /goo/
    end
  end

  describe "help" do
    it 'should show help with -h' do
      mock_pry("ls -h").should =~ /Usage: ls/
    end
  end

  describe "methods" do
    it "should show public methods by default" do
      mock_pry("ls Class.new{ def goo; end }.new").should =~ /goo/
    end

    it "should not show protected/private by default" do
      mock_pry("ls -M Class.new{ def goo; end; private :goo }").should.not =~ /goo/
      mock_pry("ls Class.new{ def goo; end; protected :goo }.new").should.not =~ /goo/
    end

    it "should show public methods with -p" do
      mock_pry("ls -p Class.new{ def goo; end }.new").should =~ /goo/
    end

    it "should show protected/private methods with -p" do
      mock_pry("ls -pM Class.new{ def goo; end; protected :goo }").should =~ /goo/
      mock_pry("ls -p Class.new{ def goo; end; private :goo }.new").should =~ /goo/
    end

    it "should work for objects with an overridden method method" do
      require 'net/http'
      # This doesn't actually touch the network, promise!
      mock_pry("ls Net::HTTP::Get.new('localhost')").should =~ /Net::HTTPGenericRequest#methods/
    end
  end

  describe "when inside Modules" do
    it "should still work" do
      mock_pry("cd Module.new{ def foobie; end }", "ls -M").should =~ /foobie/
    end
  end

  describe "constants" do
    it "should show constants defined on the current module" do
      mock_pry("class TempFoo1; BARGHL = 1; end", "ls TempFoo1").should =~ /BARGHL/
    end

    it "should not show constants defined on parent modules by default" do
      mock_pry("class TempFoo2; LHGRAB = 1; end; class TempFoo3 < TempFoo2; BARGHL = 1; end", "ls TempFoo3").should.not =~ /LHGRAB/
    end

    it "should show constants defined on ancestors with -v" do
      mock_pry("class TempFoo4; LHGRAB = 1; end; class TempFoo5 < TempFoo4; BARGHL = 1; end", "ls -v TempFoo5").should =~ /LHGRAB/
    end

    it "should not autoload constants!" do
      autoload :McflurgleTheThird, "/tmp/this-file-d000esnat-exist.rb"
      lambda{ mock_pry("ls -c") }.should.not.raise
    end
  end

  describe "grep" do
    it "should reduce the number of outputted things" do
      mock_pry("ls -c").should =~ /ArgumentError/
      mock_pry("ls -c --grep Run").should.not =~ /ArgumentError/
    end
    it "should still output matching things" do
      mock_pry("ls -c --grep Run").should =~ /RuntimeError/
    end
  end

  describe "when no arguments given" do
    describe "when at the top-level" do
      # rubinius has a bug that means local_variables of "main" aren't reported inside eval()
      unless Pry::Helpers::BaseHelpers.rbx?
        it "should show local variables" do
          mock_pry("ls").should =~ /_pry_/
          mock_pry("arbitrar = 1", "ls").should =~ /arbitrar/
        end
      end
    end

    describe "when in a class" do
      it "should show constants" do
        mock_pry("class GeFromulate1; FOOTIFICATE=1.3; end", "cd GeFromulate1", "ls").should =~ /FOOTIFICATE/
      end

      it "should show class variables" do
        mock_pry("class GeFromulate2; @@flurb=1.3; end", "cd GeFromulate2", "ls").should =~ /@@flurb/
      end

      it "should show methods" do
        mock_pry("class GeFromulate3; def self.mooflight; end ; end", "cd GeFromulate3", "ls").should =~ /mooflight/
      end
    end

    describe "when in an object" do
      it "should show methods" do
        mock_pry("cd Class.new{ def self.fooerise; end; self }", "ls").should =~ /fooerise/
      end

      it "should show instance variables" do
        mock_pry("cd Class.new", "@alphooent = 1", "ls").should =~ /@alphooent/
      end
    end
  end
end
