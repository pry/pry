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

        it 'should execute start session and end session hooks' do
          input = InputTester.new("exit")
          str_output = StringIO.new
          o = Object.new
          
          pry_tester = Pry.start(o, :input => input, :output => str_output)
          str_output.string.should =~ /Beginning.*#{o}/
          str_output.string.should =~ /Ending.*#{o}/
        end
      end

      describe "nesting" do
        after do
          Pry.reset_defaults
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

      describe "commands" do
        it 'should run command1' do
          pry_tester = Pry.new
          pry_tester.commands = CommandTester
          pry_tester.input = InputTester.new("command1", "exit_all")
          pry_tester.commands = CommandTester

          str_output = StringIO.new
          pry_tester.output = str_output

          pry_tester.rep

          str_output.string.should =~ /command1/
        end

        it 'should run command2' do
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

      describe "Pry#binding_for" do
        it 'should return TOPLEVEL_BINDING if parameter self is main' do
          _main_ = lambda { TOPLEVEL_BINDING.eval('self') }
          Pry.new.binding_for(_main_.call).is_a?(Binding).should == true
          Pry.new.binding_for(_main_.call).should == TOPLEVEL_BINDING
          Pry.new.binding_for(_main_.call).should == Pry.new.binding_for(_main_.call)
        end
      end


      describe "test Pry defaults" do

        after do
          Pry.reset_defaults
        end
        
        describe "input" do

          after do
            Pry.reset_defaults
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

        describe "commands" do
          
          it 'should set the commands default, and the default should be overridable' do
            class Command0 < Pry::CommandBase
              command "hello" do
                describe ""
                action { |opts| opts[:output].puts "hello world"; opts[:val].clear }
              end
            end

            Pry.commands = Command0

            str_output = StringIO.new
            Pry.new(:input => InputTester.new("hello"), :output => str_output).rep
            str_output.string.should =~ /hello world/

            class Command1 < Pry::CommandBase
              command "goodbye" do
                describe ""
                action { |opts| opts[:output].puts "goodbye world"; opts[:val].clear }
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
              command "h" do |v|
                v.describe "h command"
                v.action { }
              end
            end

            Command2.commands.keys.size.should == 2
            Command2.command_info.keys.include?("help").should == true
            Command2.command_info.keys.include?("h").should == true

            Object.remove_const(:Command2)
          end

          it 'should inherit comands from Pry::Commands' do
            class Command3 < Pry::Commands
              command "v" do
                action {}
              end
            end

            Command3.command_info.include?("nesting").should == true
            Command3.command_info.include?("jump_to").should == true
            Command3.command_info.include?("cd").should == true
            Command3.command_info.include?("v").should == true

            Object.remove_const(:Command3)
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
        end
      end
    end
  end
end
