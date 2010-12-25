direc = File.dirname(__FILE__)

require 'rubygems'
require 'bacon'
require "#{direc}/../lib/pry"
require "#{direc}/test_helper"

NOT_FOR_RUBY_18 = [/show_doc/, /show_idoc/, /show_method/, /show_imethod/]

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
        output = OutputTester.new
        o = Object.new

        pry_tester = Pry.new(input, output)
        pry_tester.rep(o)
        o.instance_variable_get(:@x).should == 10
      end

      it 'should make self evaluate to the receiver of the rep session' do
        output = OutputTester.new
        o = Object.new
        
        pry_tester = Pry.new(InputTester.new("self"), output)
        pry_tester.rep(o)
        output.output_buffer.should == o
      end

      it 'should work with multi-line input' do
        output = OutputTester.new
        pry_tester = Pry.new(InputTester.new("x = ", "1 + 4"), output)
        pry_tester.rep(Hello)
        output.output_buffer.should == 5
      end

      it 'should define a nested class under Hello and not on top-level or Pry' do
        output = OutputTester.new
        pry_tester = Pry.new(InputTester.new("class Nested", "end"), output)
        pry_tester.rep(Hello)
        Hello.const_defined?(:Nested).should == true
      end
    end

    describe "repl" do
      describe "basic functionality" do
        it 'should set an ivar on an object and exit the repl' do
          input_strings = ["@x = 10", "exit"]
          input = InputTester.new(*input_strings)
          output = OutputTester.new

          o = Object.new

          pry_tester = Pry.new(input, output)
          pry_tester.repl(o)

          o.instance_variable_get(:@x).should == 10
          output.session_end_invoked.should == true
        end
      end

      describe "nesting" do
        it 'should nest properly' do
          Pry.input = InputTester.new("pry", "pry", "pry", "nesting", "exit", "exit", "exit", "exit")
          Pry.output = OutputTester.new

          def (Pry.output).show_nesting(level)
            class << self; attr_reader :nest_output; end
            @nest_output = level.last.first
          end

          o = Object.new

          pry_tester = Pry.new
          pry_tester.repl(o)

          Pry.output.nest_output.should == 3
        end
      end

      describe "commands" do
        before do
          Pry.input = InputTester.new("exit")

          Pry.output = OutputTester.new
        end

        after do
          Pry.reset_defaults
        end

        commands = {
          "!" => "refresh",
          "help" => "show_help",
          "nesting" => "show_nesting",
          "status" => "show_status",
          "cat dummy" => "cat",
          "cd 3" => "cd",
          "ls" => "ls",
          "jump_to 0" => "jump_to",
          "show_method test_method" => "show_method",
          "show_imethod test_method" => "show_method",
          "show_doc test_method" => "show_doc",
          "show_idoc test_method" => "show_doc"
        }
        
        commands.each do |command, meth|

          if RUBY_VERSION =~ /1.8/ && NOT_FOR_RUBY_18.any? { |v| v =~ command }
            next
          end

          eval %{
            it "should invoke output##{meth} when #{command} command entered" do
              input_strings = ["#{command}", "exit"]
              input = InputTester.new(*input_strings)
              output = OutputTester.new
              o = Class.new
          
              pry_tester = Pry.new(input, output)
              pry_tester.repl(o)

              output.#{meth}_invoked.should == true
              output.session_end_invoked.should == true
            end
          }
        end
        
        commands.each do |command, meth|

          if RUBY_VERSION =~ /1.8/ && NOT_FOR_RUBY_18.include?(command)
            next
          end

          eval %{
            it "should raise when trying to invoke #{command} command with preceding whitespace" do
              input_strings = [" #{command}", "exit"]
              input = InputTester.new(*input_strings)
              output = OutputTester.new
              o = Class.new
          
              pry_tester = Pry.new(input, output)
              pry_tester.repl(o)

              if "#{command}" != "!"
                output.output_buffer.is_a?(NameError).should == true
              else

                # because entering " !" in pry doesnt cause error, it
                # just creates a wait prompt which the subsquent
                # "exit" escapes from
                output.output_buffer.should == ""
              end
            end
          }
        end
      end
    end
  end
end
