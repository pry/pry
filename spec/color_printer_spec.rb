RSpec.describe Pry::ColorPrinter do
  let(:output) { StringIO.new }

  describe ".pp" do
    context "when no exception is raised in #inspect" do
      let(:healthy_class) do
        Class.new do
          def inspect
            'string'
          end
        end
      end

      it "prints a string" do
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
  end
end
