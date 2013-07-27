require 'helper'

describe "reload-code" do
  before do
    @o = Object.new
    @t = pry_tester(@o)
    @tmp_dir ||= File.realpath(Dir.mktmpdir)
  end

  it "should reload the source of descendants and self" do
    file_path = File.join(@tmp_dir, "my_module.rb")

    File.open(file_path,"w") do |f|
      f.puts <<-MODEL
      class Parent
        class Child
          class Grandchild
            attr_accessor :not_foo
          end
        end
      end
      MODEL
    end

    @t.eval "require '#{file_path}'"

    File.open(file_path,"w") do |f|
      f.puts <<-MODEL
      class Parent
        attr_reader :cannot_be_without_method
        class Child
          class Grandchild
            attr_accessor :foo
          end
        end
      end
      MODEL
    end

    @t.eval("Parent::Child::Grandchild.new.respond_to?(:foo)").should == false
    @t.process_command 'reload-code -r Parent'
    @t.eval("Parent::Child::Grandchild.new.respond_to?(:foo)").should == false
  end
end


