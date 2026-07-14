# frozen_string_literal: true

require "spec_helper"

RSpec.describe EascFetcher::Docid do
  describe ".from_string" do
    it "parses ПМГ designations" do
      d = described_class.from_string("ПМГ 03-2025")
      expect(d.series).to eq("PMG")
      expect(d.number).to eq("03")
      expect(d.year).to eq("2025")
      expect(d.doctype).to eq("pmg")
    end

    it "parses ПМГ В (defense variant)" do
      d = described_class.from_string("ПМГ В 31-2001")
      expect(d.variant).to eq("V")
    end

    it "parses РМГ designations" do
      d = described_class.from_string("РМГ 151-2025")
      expect(d.series).to eq("RMG")
      expect(d.doctype).to eq("rmg")
    end
  end

  describe "#to_s" do
    it "renders canonical Cyrillic" do
      expect(described_class.from_string("РМГ 151-2025").to_s).to eq("РМГ 151-2025")
      expect(described_class.from_string("PMG V 31-2001").to_s).to eq("ПМГ В 31-2001")
    end
  end

  describe "#id / #filename_stem" do
    it "is lowercase Latin dash-separated" do
      expect(described_class.from_string("РМГ 151-2025").id).to eq("rmg-151-2025")
      expect(described_class.from_string("ПМГ В 31-2001").id).to eq("pmg-v-31-2001")
    end
  end

  describe "#urn" do
    it "delegates to Pubid::Easc" do
      expect(described_class.from_string("РМГ 151-2025").urn).to eq("urn:easc:rmg:151:2025")
    end
  end
end
