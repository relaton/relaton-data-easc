# frozen_string_literal: true

require "spec_helper"
require "relaton/index"
require "relaton/bib"
require "tmpdir"
require "zip"

RSpec.describe EascFetcher::Indexer do
  describe ".build" do
    # A PMG, an RMG, and the ПМГ В defense variant exercise every id shape.
    FIXTURES = %w[pmg-02-93 rmg-151-2025 pmg-v-31-2001].freeze

    around do |example|
      Dir.mktmpdir do |dir|
        @dir = dir
        data = File.join(dir, "data")
        Dir.mkdir(data)
        FIXTURES.each do |stem|
          src = File.expand_path("../../data/#{stem}.yaml", __dir__)
          File.write(File.join(data, "#{stem}.yaml"),
                     File.read(src, encoding: "UTF-8"))
        end
        @data_dir = data
        @index_file = File.join(dir, "index-v1.yaml")
        @index_v2_file = File.join(dir, "index-v2.yaml")
        example.run
      end
    end

    def build!
      described_class.build(
        data_dir: @data_dir,
        index_file: @index_file,
        index_v2_file: @index_v2_file,
      )
    end

    it "populates the v1 index with one entry per data file" do
      build!
      v1 = YAML.unsafe_load_file(@index_file)
      expect(v1.size).to eq(FIXTURES.size)
      expect(v1.map { |e| e[:id] }).to contain_exactly(
        "ПМГ 02-93", "РМГ 151-2025", "ПМГ В 31-2001"
      )
    end

    it "fills the structured v2 index with serialized pubid identifiers" do
      build!
      v2 = YAML.unsafe_load_file(@index_v2_file)
      expect(v2).not_to be_empty
      expect(v2.size).to eq(FIXTURES.size)
      # Every entry carries a serialized pubid hash and a file path.
      v2.each do |entry|
        expect(entry[:id]).to include("_type" => a_string_matching(/\Apubid:easc:/))
        expect(entry[:file]).to match(/\.yaml\z/)
      end
    end

    it "serializes the defense variant marker for ПМГ В" do
      build!
      v2 = YAML.unsafe_load_file(@index_v2_file)
      variant = v2.find { |e| e[:file].include?("pmg-v-31-2001") }
      expect(variant[:id]).to include(
        "_type" => "pubid:easc:pmg",
        "series" => "PMG",
        "variant" => "V",
        "number" => "31",
        "year" => "2001",
      )
    end

    it "writes a single-entry zip next to each index yaml" do
      build!
      {
        @index_file => "index-v1.yaml",
        @index_v2_file => "index-v2.yaml",
      }.each do |yaml, entry_name|
        zip = yaml.sub(/\.yaml\z/, ".zip")
        expect(File).to exist(zip)
        Zip::File.open(zip) do |z|
          expect(z.entries.map(&:name)).to eq([entry_name])
          expect(z.read(entry_name)).to eq(File.binread(yaml))
        end
      end
    end

    # Guards the shipped regression (whole index-v2.yaml was `--- []`) and the
    # property that every real data file's docid.content parses via pubid.
    it "indexes every real data file into v2 (no silently skipped entries)" do
      real_data = File.expand_path("../../data", __dir__)
      described_class.build(
        data_dir: real_data,
        index_file: @index_file,
        index_v2_file: @index_v2_file,
      )
      v1 = YAML.unsafe_load_file(@index_file)
      v2 = YAML.unsafe_load_file(@index_v2_file)
      expect(v2.size).to eq(Dir[File.join(real_data, "*.yaml")].size)
      expect(v2.size).to eq(v1.size)
    end
  end
end
