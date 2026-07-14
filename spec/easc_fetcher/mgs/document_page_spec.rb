# frozen_string_literal: true

require "spec_helper"

RSpec.describe EascFetcher::Mgs::DocumentPage do
  let(:html) do
    File.read(File.expand_path("../../fixtures/mgs/detail-pmg-110917.html", __dir__),
              encoding: "UTF-8")
  end

  describe ".parse" do
    subject(:result) { described_class.parse(html, doc_id: "110917") }

    it "captures the designation" do
      expect(result.designation).to eq("ПМГ В 31-2001")
    end

    it "captures the title" do
      expect(result.title).to start_with("Порядок оформления заявок")
    end

    it "maps status Взамен to 'replaces'" do
      expect(result.status).to eq("replaces")
    end

    it "captures developer" do
      expect(result.developer).to eq("Российская Федерация")
    end

    it "extracts joining_states array" do
      expect(result.joining_states).to include("АРМ", "ТУР", "КАЗ")
    end

    it "captures adoption_info (МГС session)" do
      expect(result.adoption_info).to eq("19МГС")
    end
  end
end
