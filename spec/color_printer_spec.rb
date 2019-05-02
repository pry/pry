# frozen_string_literal: true

RSpec.describe Pry::ColorPrinter do
  let(:output) { StringIO.new }

  describe ".default" do
    let(:output) { StringIO.new }
    let(:pry_instance) { Pry.new(output: output) }

    it "prints output prefix with value" do
      described_class.default(StringIO.new, 'foo', pry_instance)
      expect(output.string).to eq("=> \"foo\"\n")
    end
  end

  describe ".pp" do
    context "when no exception is raised in #inspect" do
      let(:healthy_class) do
        Class.new do
          def inspect
            'string'
          end
        end
      end

      it "prints a string with a newline" do
        described_class.pp(healthy_class.new, output)
        expect(output.string).to eq("string\n")
      end
    end

    context "when an exception is raised in #inspect" do
      let(:broken_class) do
        Class.new do
          def inspect
            raise
          end
        end
      end

      it "still prints a string" do
        described_class.pp(broken_class.new, output)
        expect(output.string)
          .to match(/\A\e\[32m#<#<Class:0x.+>:0x.+>\e\[0m\e\[0m\n\z/)
      end
    end

    context "when printing a BasicObject" do
      it "prints a string" do
        described_class.pp(BasicObject.new, output)
        expect(output.string)
          .to match(/\A\e\[32m#<BasicObject:0x.+>\e\[0m\e\[0m\n\z/)
      end
    end

    context "when #inspect returns an object literal" do
      let(:klass) do
        Class.new do
          def inspect
            '#<Object:0x00007fe86bab53c8>'
          end
        end
      end

      it "prints the object inspect" do
        described_class.pp(klass.new, output)
        expect(output.string).to eq("\e[32m#<Object:0x00007fe86bab53c8>\e[0m\n")
      end

      context "and when SyntaxHighlighter returns a token starting with '\e'" do
        before do
          expect(Pry::SyntaxHighlighter).to receive(:keyword_token_color)
            .and_return("\e[32m")
        end

        it "prints the object as is" do
          described_class.pp(klass.new, output)
          expect(output.string).to eq("\e[32m#<Object:0x00007fe86bab53c8>\e[0m\n")
        end
      end

      context "and when SyntaxHighlighter returns a token that doesn't start with '\e'" do
        before do
          expect(Pry::SyntaxHighlighter).to receive(:keyword_token_color)
            .and_return('token')
        end

        it "prints the object with escape characters" do
          described_class.pp(klass.new, output)
          expect(output.string)
            .to eq("\e[0m\e[0;tokenm#<Object:0x00007fe86bab53c8>\e[0m\n")
        end
      end
    end

    context "when #inspect raises Pry::Pager::StopPaging" do
      let(:klass) do
        Class.new do
          def inspect
            raise Pry::Pager::StopPaging
          end
        end
      end

      it "propagates the error" do
        expect { described_class.pp(klass.new, output) }
          .to raise_error(Pry::Pager::StopPaging)
      end
    end
  end
end
