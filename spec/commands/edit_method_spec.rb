require 'helper'

describe "edit-method" do
  describe "on a method defined in a file" do
    before do
      @tempfile = Tempfile.new(['pry', '*.rb'])
      @tempfile.puts <<-EOS
        module A
          def a
            :yup
          end

          def b
            :kinda
          end
        end

        class X
          include A

          def self.x
            :double_yup
          end

          def x
            :nope
          end

          def b
            super
          end
          alias c b

          def y?
            :because
          end

          class B
            G = :nawt

            def foo
              :possibly
              G
            end
          end
        end
      EOS
      @tempfile.flush
      load @tempfile.path
    end

    after do
      @tempfile.close(true)
    end

    describe 'without -p' do
      before do
        @old_editor = Pry.config.editor
        @file = @line = @contents = nil
        Pry.config.editor = lambda do |file, line|
          @file = file; @line = line
          nil
        end
      end
      after do
        Pry.config.editor = @old_editor
      end

      it "should correctly find a class method" do
        pry_eval 'edit-method X.x'
        @file.should == @tempfile.path
        @line.should == 14
      end

      it "should correctly find an instance method" do
        pry_eval 'edit-method X#x'
        @file.should == @tempfile.path
        @line.should == 18
      end

      it "should correctly find a method on an instance" do
        pry_eval 'x = X.new', 'edit-method x.x'
        @file.should == @tempfile.path
        @line.should == 18
      end

      it "should correctly find a method from a module" do
        pry_eval 'edit-method X#a'
        @file.should == @tempfile.path
        @line.should == 2
      end

      it "should correctly find an aliased method" do
        pry_eval 'edit-method X#c'
        @file.should == @tempfile.path
        @line.should == 22
      end
    end

    describe 'with -p' do
      before do
        @old_editor = Pry.config.editor
        Pry.config.editor = lambda do |file, line|
          lines = File.read(file).lines.to_a
          lines[1] = ":maybe\n"
          File.open(file, 'w') do |f|
            f.write(lines.join)
          end
          @patched_def = String(lines[1]).chomp
          nil
        end
      end

      after do
        Pry.config.editor = @old_editor
      end

      it "should successfully replace a class method" do
        pry_eval 'edit-method -p X.x'

        class << X
          X.method(:x).owner.should == self
        end
        X.method(:x).receiver.should == X
        X.x.should == :maybe
      end

      it "should successfully replace an instance method" do
        pry_eval 'edit-method -p X#x'

        X.instance_method(:x).owner.should == X
        X.new.x.should == :maybe
      end

      it "should successfully replace a method on an instance" do
        pry_eval 'instance = X.new', 'edit-method -p instance.x'

        instance = X.new
        instance.method(:x).owner.should == X
        instance.x.should == :maybe
      end

      it "should successfully replace a method from a module" do
        pry_eval 'edit-method -p X#a'

        X.instance_method(:a).owner.should == A
        X.new.a.should == :maybe
      end

      it "should successfully replace a method with a question mark" do
        pry_eval 'edit-method -p X#y?'

        X.instance_method(:y?).owner.should == X
        X.new.y?.should == :maybe
      end

      it "should preserve module nesting" do
        pry_eval 'edit-method -p X::B#foo'

        X::B.instance_method(:foo).owner.should == X::B
        X::B.new.foo.should == :nawt
      end

      describe "monkey-patching" do
        before do
          @edit = 'edit-method --patch ' # A shortcut.
        end

        # @param [Integer] lineno
        # @return [String] the stripped line from the tempfile at +lineno+
        def stripped_line_at(lineno)
          @tempfile.rewind
          @tempfile.lines.to_a[lineno].strip
        end

        # Applies the monkey patch for +method+ with help of evaluation of
        # +eval_strs+. The idea is to capture the initial line number (before
        # the monkey patch), because it gets overwritten by the line number from
        # the monkey patch. And our goal is to check that the original
        # definition hasn't changed.
        # @param [UnboundMethod] method
        # @param [Array<String>] eval_strs
        # @return [Array<String] the lines with definitions of the same line
        #   before monkey patching and after (normally, they should be equal)
        def apply_monkey_patch(method, *eval_strs)
          _, lineno = method.source_location
          definition_before = stripped_line_at(lineno)

          pry_eval(*eval_strs)

          definition_after = stripped_line_at(lineno)

          [definition_before, definition_after]
        end

        it "should work for a class method" do
          def_before, def_after =
            apply_monkey_patch(X.method(:x), "#@edit X.x")

          def_before.should   == ':double_yup'
          def_after.should    == ':double_yup'
          @patched_def.should == ':maybe'
        end

        it "should work for an instance method" do
          def_before, def_after =
            apply_monkey_patch(X.instance_method(:x), "#@edit X#x")

          def_before.should   == ':nope'
          def_after.should    == ':nope'
          @patched_def.should == ':maybe'
        end

        it "should work for a method on an instance" do
          def_before, def_after =
            apply_monkey_patch(X.instance_method(:x), 'instance = X.new', "#@edit instance.x")

          def_before.should   == ':nope'
          def_after.should    == ':nope'
          @patched_def.should == ':maybe'
        end

        it "should work for a method from a module" do
          def_before, def_after =
            apply_monkey_patch(X.instance_method(:a), "#@edit X#a")

          def_before.should   == ':yup'
          def_after.should    == ':yup'
          @patched_def.should == ':maybe'
        end

        it "should work for a method with a question mark" do
          def_before, def_after =
            apply_monkey_patch(X.instance_method(:y?), "#@edit X#y?")

          def_before.should   == ':because'
          def_after.should    == ':because'
          @patched_def.should == ':maybe'
        end

        it "should work with nesting" do
          def_before, def_after =
            apply_monkey_patch(X::B.instance_method(:foo), "#@edit X::B#foo")

          def_before.should   == ':possibly'
          def_after.should    == ':possibly'
          @patched_def.should == ':maybe'
        end
      end
    end

    describe 'on an aliased method' do
      before do
        @old_editor = Pry.config.editor
        Pry.config.editor = lambda do |file, line|
          lines = File.read(file).lines.to_a
          lines[1] = '"#{super}aa".to_sym' + "\n"
          File.open(file, 'w') do |f|
            f.write(lines.join)
          end
          nil
        end
      end
      after do
        Pry.config.editor = @old_editor
      end

      it "should change the alias, but not the original, without breaking super" do
        pry_eval 'edit-method -p X#c'

        Pry::Method.from_str("X#c").alias?.should == true

        X.new.b.should == :kinda
        X.new.c.should == :kindaaa
      end
    end

    describe 'with three-arg editor' do
      before do
        @old_editor = Pry.config.editor
        @file = @line = @reloading = nil
        Pry.config.editor = lambda do |file, line, reloading|
          @file = file; @line = line; @reloading = reloading
          nil
        end
      end
      after do
        Pry.config.editor = @old_editor
      end

      it "should pass the editor a reloading arg" do
        pry_eval 'edit-method X.x'
        @reloading.should == true
        pry_eval 'edit-method -n X.x'
        @reloading.should == false
      end
    end
  end
end
