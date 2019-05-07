# frozen_string_literal: true

describe Pry::Ring do
  let(:ring) { described_class.new(3) }

  describe "#<<" do
    it "adds elements as is when the ring is not full" do
      ring << 1 << 2 << 3
      expect(ring.to_a).to eq([1, 2, 3])
    end

    it "overwrites elements when the ring is full" do
      ring << 1 << 2 << 3 << 4 << 5
      expect(ring.to_a).to eq([3, 4, 5])
    end

    it "keeps duplicate elements" do
      ring << 1 << 1 << 1 << 1
      expect(ring.to_a).to eq([1, 1, 1])
    end
  end

  describe "#[]" do
    context "when the ring is empty" do
      it "returns nil" do
        expect(ring[0]).to be_nil
      end
    end

    context "when the ring is not full" do
      before { ring << 1 << 2 << 3 }

      it "reads elements" do
        expect(ring[0]).to eq(1)
        expect(ring[1]).to eq(2)
        expect(ring[2]).to eq(3)

        expect(ring[-1]).to eq(3)
        expect(ring[-2]).to eq(2)
        expect(ring[-3]).to eq(1)
      end

      it "reads elements via range" do
        expect(ring[1..2]).to eq([2, 3])
        expect(ring[-2..-1]).to eq([2, 3])
      end
    end

    context "when the ring is full" do
      before { ring << 1 << 2 << 3 << 4 << 5 }

      it "reads elements" do
        expect(ring[0]).to eq(3)
        expect(ring[1]).to eq(4)
        expect(ring[2]).to eq(5)

        expect(ring[-1]).to eq(5)
        expect(ring[-2]).to eq(4)
        expect(ring[-3]).to eq(3)
      end

      it "returns the first element when accessed through 0..0" do
        expect(ring[0..0]).to eq([3])
      end

      it "reads elements via inclusive range" do
        expect(ring[1..2]).to eq([4, 5])
        expect(ring[-2..-1]).to eq([4, 5])
        expect(ring[-2..3]).to eq([4, 5])

        expect(ring[0..-1]).to eq([3, 4, 5])

        expect(ring[2..-1]).to eq([5])
        expect(ring[-1..10]).to eq([5])

        expect(ring[-1..0]).to eq([])
        expect(ring[-1..1]).to eq([])
      end

      it "reads elements via exclusive range" do
        expect(ring[1...2]).to eq([4])
        expect(ring[-2...-1]).to eq([4])
        expect(ring[-2...3]).to eq([4, 5])

        expect(ring[0...-1]).to eq([3, 4])

        expect(ring[2...-1]).to eq([])
        expect(ring[-1...10]).to eq([5])

        expect(ring[-1...0]).to eq([])
        expect(ring[-1...1]).to eq([])
      end
    end
  end

  describe "#to_a" do
    it "returns a duplicate of internal buffer" do
      array = ring.to_a
      ring << 1
      expect(array.count).to eq(0)
      expect(ring.count).to eq(1)
    end
  end

  describe "#clear" do
    it "resets ring to initial state" do
      ring << 1
      expect(ring.count).to eq(1)
      expect(ring.to_a).to eq([1])

      ring.clear
      expect(ring.count).to eq(0)
      expect(ring.to_a).to eq([])
    end
  end
end
