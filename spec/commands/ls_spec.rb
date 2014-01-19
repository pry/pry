require 'helper'

describe "ls" do
  describe "below ceiling" do
    it "should stop before Object by default" do
      pry_eval("cd Class.new{ def goo; end }.new", "ls").should.not =~ /Object/
      pry_eval("cd Class.new{ def goo; end }", "ls -M").should.not =~ /Object/
    end

    it "should include object if -v is given" do
      pry_eval("cd Class.new{ def goo; end }.new", "ls -m -v").should =~ /Object/
      pry_eval("cd Class.new{ def goo; end }", "ls -vM").should =~ /Object/
    end

    it "should include super-classes by default" do
      pry_eval(
        "cd Class.new(Class.new{ def goo; end; public :goo }).new",
        "ls").should =~ /goo/

      pry_eval(
        "cd Class.new(Class.new{ def goo; end; public :goo })",
        "ls -M").should =~ /goo/
    end

    it "should not include super-classes when -q is given" do
      pry_eval("cd Class.new(Class.new{ def goo; end }).new", "ls -q").should.not =~ /goo/
      pry_eval("cd Class.new(Class.new{ def goo; end })", "ls -M -q").should.not =~ /goo/
    end
  end

  describe "help" do
    it 'should show help with -h' do
      pry_eval("ls -h").should =~ /Usage: ls/
    end
  end

  if defined?(BasicObject)
    describe "BasicObject" do
      it "should work on BasicObject" do
        pry_eval("ls BasicObject.new").should =~ /BasicObject#methods:.*__send__/m
      end

      it "should work on subclasses of BasicObject" do
        pry_eval(
          "class LessBasic < BasicObject; def jaroussky; 5; end; end",
          "ls LessBasic.new"
        ).should =~ /LessBasic#methods:.*jaroussky/m
      end
    end
  end

  describe "methods" do
    it "should show public methods by default" do
      output = pry_eval("ls Class.new{ def goo; end; public :goo }.new")
      output.should =~ /methods: goo/
    end

    it "should not show protected/private by default" do
      pry_eval("ls -M Class.new{ def goo; end; private :goo }").should.not =~ /goo/
      pry_eval("ls Class.new{ def goo; end; protected :goo }.new").should.not =~ /goo/
    end

    it "should show public methods with -p" do
      pry_eval("ls -p Class.new{ def goo; end }.new").should =~ /methods: goo/
    end

    it "should show protected/private methods with -p" do
      pry_eval("ls -pM Class.new{ def goo; end; protected :goo }").should =~ /methods: goo/
      pry_eval("ls -p Class.new{ def goo; end; private :goo }.new").should =~ /methods: goo/
    end

    it "should work for objects with an overridden method method" do
      require 'net/http'
      # This doesn't actually touch the network, promise!
      pry_eval("ls Net::HTTP::Get.new('localhost')").should =~ /Net::HTTPGenericRequest#methods/
    end

    it "should work for objects which instance_variables returns array of symbol but there is no Symbol#downcase" do
      test_case = "class Object; alias :fg :instance_variables; def instance_variables; fg.map(&:to_sym); end end;"
      normalize = "class Object; def instance_variables; fg; end end;"

      test = lambda do
        begin
          pry_eval(test_case, "class GeFromulate2; @flurb=1.3; end", "cd GeFromulate2", "ls")
          pry_eval(normalize)
        rescue
          pry_eval(normalize)
          raise
        end
      end

      test.should.not.raise
    end

    it "should show error message when instance is given with -M option" do
      error = lambda{ pry_eval("ls -M String.new") }.should.raise(Pry::CommandError)
      error.message.should.match(/-M only makes sense with a Module or a Class/)
    end


    # see: https://travis-ci.org/pry/pry/jobs/5071918
    unless Pry::Helpers::BaseHelpers.rbx?
      it "should handle classes that (pathologically) define .ancestors" do
        output = pry_eval("ls Class.new{ def self.ancestors; end; def hihi; end }")
        output.should =~ /hihi/
      end
    end
  end

  describe 'with -l' do
    it 'should find locals and sort by descending size' do
      result = pry_eval("aa = 'asdf'; bb = 'xyz'", 'ls -l')
      result.should.not =~ /=>/
      result.should.not =~ /0x\d{5}/
      result.should =~ /asdf.*xyz/m
    end
    it 'should not list pry noise' do
      pry_eval('ls -l').should.not =~ /_(?:dir|file|ex|pry|out|in)_/
    end
  end

  describe "when inside Modules" do
    it "should still work" do
      pry_eval(
        "cd Module.new{ def foobie; end; public :foobie }",
        "ls -M").should =~ /foobie/
    end

    it "should work for ivars" do
      pry_eval(
        "module StigmaT1sm; def foobie; @@gharble = 456; end; end",
        "Object.new.tap{ |o| o.extend(StigmaT1sm) }.foobie",
        "cd StigmaT1sm",
        "ls -i").should =~ /@@gharble/
    end

    it "should include instance methods by default" do
      output = pry_eval(
        "ls Module.new{ def shinanagarns; 4; end; public :shinanagarns }")
      output.should =~ /shinanagarns/
    end

    it "should behave normally when invoked on Module itself" do
      pry_eval("ls Module").should.not =~ /Pry/
    end
  end

  describe "constants" do
    it "works on top-level" do
      toplevel_consts = pry_eval('ls -c')
      [/RUBY_PLATFORM/, /ARGF/, /STDOUT/].each do |const|
        toplevel_consts.should =~ const
      end
    end

    it "should show constants defined on the current module" do
      pry_eval("class TempFoo1; BARGHL = 1; end", "ls TempFoo1").should =~ /BARGHL/
    end

    it "should not show constants defined on parent modules by default" do
      pry_eval("class TempFoo2; LHGRAB = 1; end; class TempFoo3 < TempFoo2; BARGHL = 1; end", "ls TempFoo3").should.not =~ /LHGRAB/
    end

    it "should show constants defined on ancestors with -v" do
      pry_eval("class TempFoo4; LHGRAB = 1; end; class TempFoo5 < TempFoo4; BARGHL = 1; end", "ls -v TempFoo5").should =~ /LHGRAB/
    end

    it "should not autoload constants!" do
      autoload :McflurgleTheThird, "/tmp/this-file-d000esnat-exist.rb"
      lambda{ pry_eval("ls -c") }.should.not.raise
    end

    it "should show constants for an object's class regardless of mixins" do
      pry_eval(
        "cd Pry.new",
        "extend Module.new",
        "ls -c"
      ).should.match(/Method/)
    end
  end

  describe "grep" do
    it "should reduce the number of outputted things" do
      pry_eval("ls -c Object").should =~ /ArgumentError/
      pry_eval("ls -c Object --grep Run").should.not =~ /ArgumentError/
    end

    it "should still output matching things" do
      pry_eval("ls -c Object --grep Run").should =~ /RuntimeError/
    end
  end

  describe "when no arguments given" do
    describe "when at the top-level" do
      # rubinius has a bug that means local_variables of "main" aren't reported inside eval()
      unless Pry::Helpers::BaseHelpers.rbx?
        it "should show local variables" do
          pry_eval("ls").should =~ /_pry_/
          pry_eval("arbitrar = 1", "ls").should =~ /arbitrar/
        end
      end
    end

    describe "when in a class" do
      it "should show constants" do
        pry_eval("class GeFromulate1; FOOTIFICATE=1.3; end", "cd GeFromulate1", "ls").should =~ /FOOTIFICATE/
      end

      it "should show class variables" do
        pry_eval("class GeFromulate2; @@flurb=1.3; end", "cd GeFromulate2", "ls").should =~ /@@flurb/
      end

      it "should show methods" do
        pry_eval("class GeFromulate3; def self.mooflight; end ; end", "cd GeFromulate3", "ls").should =~ /mooflight/
      end
    end

    describe "when in an object" do
      it "should show methods" do
        pry_eval("cd Class.new{ def self.fooerise; end; self }", "ls").should =~ /fooerise/
      end

      it "should show instance variables" do
        pry_eval("cd Class.new", "@alphooent = 1", "ls").should =~ /@alphooent/
      end
    end
  end

  if Pry::Helpers::BaseHelpers.jruby?
    describe 'on java objects' do
      it 'should omit java-esque aliases by default' do
        pry_eval('ls java.lang.Thread.current_thread').should =~ /\bthread_group\b/
        pry_eval('ls java.lang.Thread.current_thread').should.not =~ /\bgetThreadGroup\b/
      end

      it 'should include java-esque aliases if requested' do
        pry_eval('ls java.lang.Thread.current_thread -J').should =~ /\bthread_group\b/
        pry_eval('ls java.lang.Thread.current_thread -J').should =~ /\bgetThreadGroup\b/
      end
    end
  end
end
