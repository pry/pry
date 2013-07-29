require 'helper'

unless Pry::Helpers::BaseHelpers.mri_18?
  describe "reload-code" do

    before do
      @o = Object.new
      @t = pry_tester(@o)
    end

    it "should reload the source of descendants and self" do
      Dir.mktmpdir do |dir|
        tmp_file = Pathname.new(dir).realpath.join("my_module.rb")
        File.open(tmp_file,"w") do |f|
          f.puts <<-MODEL
          class Parent
            attr_accessor :method_must_exist_to_lookup
            module Child
              class Grandchild
                attr_accessor :not_foo
              end
            end
          end
          MODEL
        end

        @t.eval "require '#{tmp_file}'"

        File.open(tmp_file,"w") do |f|
          f.puts <<-MODEL
          class Parent
            attr_accessor :method_must_exist_to_lookup
            module Child
              class Grandchild
                attr_accessor :foo
              end
            end
          end
          MODEL
        end

        @t.eval("Parent::Child::Grandchild.new.respond_to?(:foo)").should == false
        @t.process_command 'reload-code -r Parent'
        @t.eval("Parent::Child::Grandchild.new.respond_to?(:foo)").should == true
      end
    end

    it "not recurse infinitely when given a circular reference" do
      Dir.mktmpdir do |dir|
        tmp_file = Pathname.new(dir).realpath.join("my_module.rb")
        File.open(tmp_file,"w") do |f|
          f.puts <<-MODEL
          module Fred
            attr_accessor :method_must_exist_to_lookup
            module Daphne
              attr_accessor :method_must_exist_to_lookup
              Scooby = ::Fred
            end
          end
          MODEL
        end

        @t.eval "require '#{tmp_file}'"
        @t.process_command 'reload-code -r Fred'
        true.should == true
      end
    end
  end
end
