direc = File.dirname(__FILE__)

require 'rubygems'
require 'bacon'
require "#{direc}/../lib/pry"
require "#{direc}/test_helper"

puts "Ruby Version #{RUBY_VERSION}"
puts "Testing Pry #{Pry::VERSION}"
puts "With method_source version #{MethodSource::VERSION}"
puts "--"

describe Pry do
  describe "open a Pry session on an object" do
    describe "rep" do
      before do
        class Hello
        end
      end

      after do
        Object.send(:remove_const, :Hello)
      end

      it 'should set an ivar on an object' do
        input_string = "@x = 10"
        input = InputTester.new(input_string)
        o = Object.new

        pry_tester = Pry.new(:input => input, :output => Pry::NullOutput)
        pry_tester.rep(o)
        o.instance_variable_get(:@x).should == 10
      end

      it 'should make self evaluate to the receiver of the rep session' do
        o = Object.new
        str_output = StringIO.new
        
        pry_tester = Pry.new(:input => InputTester.new("self"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should =~ /#{o.to_s}/
      end

      it 'should work with multi-line input' do
        o = Object.new
        str_output = StringIO.new
        
        pry_tester = Pry.new(:input => InputTester.new("x = ", "1 + 4"), :output => str_output)
        pry_tester.rep(o)
        str_output.string.should =~ /5/
      end

      it 'should define a nested class under Hello and not on top-level or Pry' do
        pry_tester = Pry.new(:input => InputTester.new("class Nested", "end"), :output => Pry::NullOutput)
        pry_tester.rep(Hello)
        Hello.const_defined?(:Nested).should == true
      end
    end

    describe "repl" do
      describe "basic functionality" do
        it 'should set an ivar on an object and exit the repl' do
          input_strings = ["@x = 10", "exit"]
          input = InputTester.new(*input_strings)

          o = Object.new

          pry_tester = Pry.start(o, :input => input, :output => Pry::NullOutput)

          o.instance_variable_get(:@x).should == 10
        end

        # # this is now deprecated
        # it 'should execute start session and end session hooks' do
        #   next
        #   input = InputTester.new("exit")
        #   str_output = StringIO.new
        #   o = Object.new
          
        #   pry_tester = Pry.start(o, :input => input, :output => str_output)
        #   str_output.string.should =~ /Beginning.*#{o}/
        #   str_output.string.should =~ /Ending.*#{o}/
        # end
      end

      describe "test loading rc files" do
        after do
          Pry::RC_FILES.clear
          Pry.should_load_rc = false
        end

        it "should run the rc file only once" do
          Pry.should_load_rc = true
          Pry::RC_FILES << "#{direc}/testrc"

          Pry.start(self, :input => StringIO.new("exit\n"), :output => Pry::NullOutput)
          TEST_RC.should == [0]

          Pry.start(self, :input => StringIO.new("exit\n"), :output => Pry::NullOutput)
          TEST_RC.should == [0]

          Object.remove_const(:TEST_RC)
        end

        it "should not run the rc file at all if Pry.should_load_rc is false" do
          Pry.should_load_rc = false
          Pry.start(self, :input => StringIO.new("exit\n"), :output => Pry::NullOutput)
          Object.const_defined?(:TEST_RC).should == false
        end

        it "should not load the rc file if #repl method invoked" do
          Pry.should_load_rc = true
          Pry.new(:input => StringIO.new("exit\n"), :output => Pry::NullOutput).repl(self)
          Object.const_defined?(:TEST_RC).should == false
          Pry.should_load_rc = false
        end
      end
      
      describe "nesting" do
        after do
          Pry.reset_defaults
          Pry.color = false
        end
        
        it 'should nest properly' do
          Pry.input = InputTester.new("pry", "pry", "pry", "\"nest:\#\{Pry.nesting.level\}\"", "exit_all")

          str_output = StringIO.new
          Pry.output = str_output

          o = Object.new

          pry_tester = o.pry
          str_output.string.should =~ /nest:3/
        end
      end

      describe "defining methods" do
        it 'should define a method on the singleton class of an object when performing "def meth;end" inside the object' do
          [Object.new, {}, []].each do |val|
            str_input = StringIO.new("def hello;end")
            Pry.new(:input => str_input, :output => StringIO.new).rep(val)
            
            val.methods(false).map(&:to_sym).include?(:hello).should == true
          end
        end

        it 'should define an instance method on the module when performing "def meth;end" inside the module' do
          str_input = StringIO.new("def hello;end")
          hello = Module.new
          Pry.new(:input => str_input, :output => StringIO.new).rep(hello)
          hello.instance_methods(false).map(&:to_sym).include?(:hello).should == true
        end

        it 'should define an instance method on the class when performing "def meth;end" inside the class' do
          str_input = StringIO.new("def hello;end")
          hello = Class.new
          Pry.new(:input => str_input, :output => StringIO.new).rep(hello)
          hello.instance_methods(false).map(&:to_sym).include?(:hello).should == true
        end

        it 'should define a method on the class of an object when performing "def meth;end" inside an immediate value or Numeric' do
          # should include  float in here, but test fails for some reason
          # on 1.8.7, no idea why!
          [:test, 0, true, false, nil].each do |val|
            str_input = StringIO.new("def hello;end")
            Pry.new(:input => str_input, :output => StringIO.new).rep(val)
            val.class.instance_methods(false).map(&:to_sym).include?(:hello).should == true
          end
        end
        
      end        
        

      describe "commands" do
        it 'should run a command with no parameter' do
          pry_tester = Pry.new
          pry_tester.commands = CommandTester
          pry_tester.input = InputTester.new("command1", "exit_all")
          pry_tester.commands = CommandTester

          str_output = StringIO.new
          pry_tester.output = str_output

          pry_tester.rep

          str_output.string.should =~ /command1/
        end

        it 'should run a command with one parameter' do
          pry_tester = Pry.new
          pry_tester.commands = CommandTester
          pry_tester.input = InputTester.new("command2 horsey", "exit_all")
          pry_tester.commands = CommandTester

          str_output = StringIO.new
          pry_tester.output = str_output

          pry_tester.rep

          str_output.string.should =~ /horsey/
        end
      end

      describe "Object#pry" do

        after do
          Pry.reset_defaults
          Pry.color = false
        end
        
        it "should start a pry session on the receiver (first form)" do
          Pry.input = InputTester.new("self", "exit")

          str_output = StringIO.new
          Pry.output = str_output

          20.pry

          str_output.string.should =~ /20/
        end

        it "should start a pry session on the receiver (second form)" do
          Pry.input = InputTester.new("self", "exit")

          str_output = StringIO.new
          Pry.output = str_output

          pry 20
          
          str_output.string.should =~ /20/
        end

        it "should error if more than one argument is passed to Object#pry" do
          lambda { pry(20, :input => Readline) }.should.raise ArgumentError
        end
      end

      describe "Pry.binding_for" do
        it 'should return TOPLEVEL_BINDING if parameter self is main' do
          _main_ = lambda { TOPLEVEL_BINDING.eval('self') }
          Pry.binding_for(_main_.call).is_a?(Binding).should == true
          Pry.binding_for(_main_.call).should == TOPLEVEL_BINDING
          Pry.binding_for(_main_.call).should == Pry.binding_for(_main_.call)
        end
      end


      describe "test Pry defaults" do

        after do
          Pry.reset_defaults
          Pry.color = false
        end
        
        describe "input" do

          after do
            Pry.reset_defaults
            Pry.color = false
          end
          
          it 'should set the input default, and the default should be overridable' do
            Pry.input = InputTester.new("5")

            str_output = StringIO.new
            Pry.output = str_output
            Pry.new.rep
            str_output.string.should =~ /5/

            Pry.new(:input => InputTester.new("6")).rep
            str_output.string.should =~ /6/
          end

          it 'should pass in the prompt if readline arity is 1' do
            Pry.prompt = proc { "A" }

            arity_one_input = Class.new do
              attr_accessor :prompt
              def readline(prompt)
                @prompt = prompt
                "exit"
              end
            end.new

            Pry.start(self, :input => arity_one_input, :output => Pry::NullOutput)
            arity_one_input.prompt.should == Pry.prompt.call
          end

          it 'should not pass in the prompt if the arity is 0' do
            Pry.prompt = proc { "A" }

            arity_zero_input = Class.new do
              def readline
                "exit"
              end
            end.new

            lambda { Pry.start(self, :input => arity_zero_input, :output => Pry::NullOutput) }.should.not.raise Exception
          end

          it 'should not pass in the prompt if the arity is -1' do
            Pry.prompt = proc { "A" }

            arity_multi_input = Class.new do
              attr_accessor :prompt
              
              def readline(*args)
                @prompt = args.first
                "exit"
              end
            end.new

            Pry.start(self, :input => arity_multi_input, :output => Pry::NullOutput)
            arity_multi_input.prompt.should == nil
          end
          
        end

        it 'should set the output default, and the default should be overridable' do
          Pry.input = InputTester.new("5", "6", "7")
          
          str_output = StringIO.new
          Pry.output = str_output
          
          Pry.new.rep
          str_output.string.should =~ /5/

          Pry.new.rep
          str_output.string.should =~ /5\n.*6/

          str_output2 = StringIO.new
          Pry.new(:output => str_output2).rep
          str_output2.string.should.not =~ /5\n.*6/
          str_output2.string.should =~ /7/
        end

        describe "Pry.run_command" do
          before do
            class RCTest
              def a() end
              B = 20
              @x = 10
            end
          end

          after do
            Object.remove_const(:RCTest)
          end
          
          it "should execute command in the appropriate object context" do
            result = Pry.run_command "ls", :context => RCTest
            result.map(&:to_sym).should == [:@x]
          end

          it "should execute command with parameters in the appropriate object context" do
            result = Pry.run_command "ls -M", :context => RCTest
            result.map(&:to_sym).should == [:a]
          end

          it "should execute command and show output with :show_output => true flag" do
            str = StringIO.new
            Pry.output = str
            result = Pry.run_command "ls -av", :context => RCTest, :show_output => true
            str.string.should =~ /global variables/
            Pry.output = $stdout
          end

          it "should execute command with multiple parameters" do
            result = Pry.run_command "ls -c -M RCTest"
            result.map(&:to_sym).should == [:a, :B]
          end
        end

        describe "commands" do
          it 'should define a command that keeps its return value' do
            class Command68 < Pry::CommandBase
              command "hello", "", :keep_retval => true do
                :kept_hello
              end
            end
            str_output = StringIO.new
            Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => Command68).rep
            str_output.string.should =~ /:kept_hello/

            Object.remove_const(:Command68)
          end

          it 'should define a command that does NOT keep its return value' do
            class Command68 < Pry::CommandBase
              command "hello", "", :keep_retval => false do
                :kept_hello
              end
            end
            str_output = StringIO.new
            Pry.new(:input => StringIO.new("hello\n"), :output => str_output, :commands => Command68).rep
            (str_output.string =~ /:kept_hello/).should == nil

            Object.remove_const(:Command68)
          end
          
          
          it 'should set the commands default, and the default should be overridable' do
            class Command0 < Pry::CommandBase
              command "hello" do
                output.puts "hello world"
              end
            end

            Pry.commands = Command0

            str_output = StringIO.new
            Pry.new(:input => InputTester.new("hello"), :output => str_output).rep
            str_output.string.should =~ /hello world/

            class Command1 < Pry::CommandBase
              command "goodbye", "" do
                output.puts "goodbye world"
              end
            end

            str_output = StringIO.new
            
            Pry.new(:input => InputTester.new("goodbye"), :output => str_output, :commands => Command1).rep
            str_output.string.should =~ /goodbye world/

            Object.remove_const(:Command0)
            Object.remove_const(:Command1)
          end

          it 'should inherit "help" command from Pry::CommandBase' do
            class Command2 < Pry::CommandBase
              command "h", "h command" do
              end
            end

            Command2.commands.keys.size.should == 3
            Command2.commands.keys.include?("help").should == true
            Command2.commands.keys.include?("install").should == true
            Command2.commands.keys.include?("h").should == true

            Object.remove_const(:Command2)
          end

          it 'should inherit commands from Pry::Commands' do
            class Command3 < Pry::Commands
              command "v" do
              end
            end

            Command3.commands.include?("nesting").should == true
            Command3.commands.include?("jump-to").should == true
            Command3.commands.include?("cd").should == true
            Command3.commands.include?("v").should == true

            Object.remove_const(:Command3)
          end

          it 'should alias a command with another command' do
            class Command6 < Pry::CommandBase
              alias_command "help2", "help"
            end

            Command6.commands["help2"].should == Command6.commands["help"]
            # str_output = StringIO.new
            # Pry.new(:input => InputTester.new("run_v"), :output => str_output, :commands => Command3).rep
            # str_output.string.should =~ /v command/

            Object.remove_const(:Command6)
          end

          it 'should change description of a command using desc' do
            
            class Command7 < Pry::Commands
            end

            orig = Command7.commands["help"][:description]

            class Command7
              desc "help", "blah"
            end

            Command7.commands["help"][:description].should.not == orig
            Command7.commands["help"][:description].should == "blah"
            
            Object.remove_const(:Command7)
          end
          
          it 'should run a command from within a command' do
            class Command01 < Pry::Commands
              command "v" do
                output.puts "v command"
              end

              command "run_v" do
                run target, "v"
              end
            end

            str_output = StringIO.new
            Pry.new(:input => InputTester.new("run_v"), :output => str_output, :commands => Command01).rep
            str_output.string.should =~ /v command/

            Object.remove_const(:Command01)
          end

          it 'should enable an inherited method to access opts and output and target, due to instance_exec' do
            class Command3 < Pry::Commands
              command "v" do
                output.puts "#{target.eval('self')}"
              end
            end

            class Command4 < Command3
            end

            str_output = StringIO.new
            Pry.new(:print => proc {}, :input => InputTester.new("v"),
                    :output => str_output, :commands => Command4).rep("john")

            str_output.string.rstrip.should == "john"

            Object.remove_const(:Command3)
            Object.remove_const(:Command4)
          end

          it 'should import commands from another command object' do
            Object.remove_const(:Command77) if Object.const_defined?(:Command77)

            class Command77 < Pry::CommandBase
              import_from Pry::Commands, "status", "jump-to"
            end

            str_output = StringIO.new
            Pry.new(:print => proc {}, :input => InputTester.new("status"),
                    :output => str_output, :commands => Command77).rep("john")
            str_output.string.should =~ /Status:/

            Object.remove_const(:Command77)
          end

          it 'should delete some inherited commands when using delete method' do
            class Command3 < Pry::Commands
              command "v" do
              end
              
              delete "show_doc", "show_method"
              delete "ls"
            end

            Command3.commands.include?("nesting").should == true
            Command3.commands.include?("jump-to").should == true
            Command3.commands.include?("cd").should == true
            Command3.commands.include?("v").should == true
            Command3.commands.include?("show_doc").should == false
            Command3.commands.include?("show_method").should == false
            Command3.commands.include?("ls").should == false

            Object.remove_const(:Command3)
          end

          it 'should override some inherited commands' do
            class Command3 < Pry::Commands
              command "jump-to" do
                output.puts "jump-to the music"
              end

              command "help" do
                output.puts "help to the music"
              end
            end

            # suppress evaluation output
            Pry.print = proc {}
            
            str_output = StringIO.new
            Pry.new(:input => InputTester.new("jump-to"), :output => str_output, :commands => Command3).rep
            str_output.string.rstrip.should == "jump-to the music"

            str_output = StringIO.new
            Pry.new(:input => InputTester.new("help"), :output => str_output, :commands => Command3).rep
            str_output.string.rstrip.should == "help to the music"
            
            Object.remove_const(:Command3)

            Pry.reset_defaults
            Pry.color = false
          end
        end

        it "should set the print default, and the default should be overridable" do
          new_print = proc { |out, value| out.puts value }
          Pry.print =  new_print

          Pry.new.print.should == Pry.print
          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
          str_output.string.should == "test\n"

          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output,
                  :print => proc { |out, value| out.puts value.reverse }).rep
          str_output.string.should == "tset\n"
          
          Pry.new.print.should == Pry.print
          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
          str_output.string.should == "test\n"
        end

        describe "pry return values" do
          it 'should return the target object' do
            Pry.start(self, :input => StringIO.new("exit"), :output => Pry::NullOutput).should == self
          end

          it 'should return the parameter given to exit' do
            Pry.start(self, :input => StringIO.new("exit 10"), :output => Pry::NullOutput).should == 10
          end

          it 'should return the parameter (multi word string) given to exit' do
            Pry.start(self, :input => StringIO.new("exit \"john mair\""), :output => Pry::NullOutput).should == "john mair"
          end

          it 'should return the parameter (function call) given to exit' do
            Pry.start(self, :input => StringIO.new("exit 'abc'.reverse"), :output => Pry::NullOutput).should == 'cba'
          end

          it 'should return the parameter (self) given to exit' do
            Pry.start("carl", :input => StringIO.new("exit self"), :output => Pry::NullOutput).should == "carl"
          end
        end
        
        describe "prompts" do
          it 'should set the prompt default, and the default should be overridable (single prompt)' do
            new_prompt = proc { "test prompt> " }
            Pry.prompt =  new_prompt

            Pry.new.prompt.should == Pry.prompt
            Pry.new.select_prompt(true, 0).should == "test prompt> "
            Pry.new.select_prompt(false, 0).should == "test prompt> "

            new_prompt = proc { "A" }
            pry_tester = Pry.new(:prompt => new_prompt)
            pry_tester.prompt.should == new_prompt
            pry_tester.select_prompt(true, 0).should == "A"
            pry_tester.select_prompt(false, 0).should == "A"
                                 
            Pry.new.prompt.should == Pry.prompt
            Pry.new.select_prompt(true, 0).should == "test prompt> "
            Pry.new.select_prompt(false, 0).should == "test prompt> "
          end

          it 'should set the prompt default, and the default should be overridable (multi prompt)' do
            new_prompt = [proc { "test prompt> " }, proc { "test prompt* " }]
            Pry.prompt =  new_prompt

            Pry.new.prompt.should == Pry.prompt
            Pry.new.select_prompt(true, 0).should == "test prompt> "
            Pry.new.select_prompt(false, 0).should == "test prompt* "

            new_prompt = [proc { "A" }, proc { "B" }]
            pry_tester = Pry.new(:prompt => new_prompt)
            pry_tester.prompt.should == new_prompt
            pry_tester.select_prompt(true, 0).should == "A"
            pry_tester.select_prompt(false, 0).should == "B"
                                 
            Pry.new.prompt.should == Pry.prompt
            Pry.new.select_prompt(true, 0).should == "test prompt> "
            Pry.new.select_prompt(false, 0).should == "test prompt* "
          end
        end

        it 'should set the hooks default, and the default should be overridable' do
          Pry.input = InputTester.new("exit")
          Pry.hooks = {
            :before_session => proc { |out,_| out.puts "HELLO" },
            :after_session => proc { |out,_| out.puts "BYE" }
          }
          
          str_output = StringIO.new
          Pry.new(:output => str_output).repl
          str_output.string.should =~ /HELLO/
          str_output.string.should =~ /BYE/
          
          Pry.input.rewind

          str_output = StringIO.new
          Pry.new(:output => str_output,
                  :hooks => {
                    :before_session => proc { |out,_| out.puts "MORNING" },
                    :after_session => proc { |out,_| out.puts "EVENING" }
                  }
                  ).repl

          str_output.string.should =~ /MORNING/
          str_output.string.should =~ /EVENING/

          # try below with just defining one hook
          Pry.input.rewind
          str_output = StringIO.new
          Pry.new(:output => str_output,
                  :hooks => {
                    :before_session => proc { |out,_| out.puts "OPEN" }
                  }
                  ).repl
          
          str_output.string.should =~ /OPEN/

          Pry.input.rewind
          str_output = StringIO.new
          Pry.new(:output => str_output,
                  :hooks => {
                    :after_session => proc { |out,_| out.puts "CLOSE" }
                  }
                  ).repl

          str_output.string.should =~ /CLOSE/

          Pry.reset_defaults
          Pry.color = false
        end
      end
    end
  end
end
