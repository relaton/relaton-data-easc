# frozen_string_literal: true

require "relaton/index"
require "relaton/bib"
require "relaton/easc"

module EascFetcher
  module Indexer
    module_function

    def build(data_dir:, index_file:, index_v2_file: nil)
      idx = clean_index(file: index_file)
      pubid_class = resolve_pubid_class
      idx2 = structured_index(index_v2_file, pubid_class)
      base = File.dirname(File.expand_path(index_file))

      Dir[File.join(data_dir, "*.yaml")].sort.each do |f|
        item = Relaton::Easc::Item.from_yaml(File.read(f, encoding: "UTF-8"))
        docid = item.docidentifier.find(&:primary) || item.docidentifier.first
        unless docid
          warn "Error processing #{f}: no docidentifier"
          next
        end
        rel = File.expand_path(f).delete_prefix("#{base}/")
        idx.add_or_update docid.content, rel
        add_pubid(idx2, pubid_class, item.id, rel) if idx2
      rescue StandardError => e
        warn "Error processing #{f}: #{e.message}"
      end

      idx.save
      idx2&.save
      [idx, idx2]
    end

    def clean_index(file:, pubid_class: nil)
      idx = Relaton::Index.find_or_create :Easc, file: file, pubid_class: pubid_class
      idx.remove_all
      idx
    end

    def structured_index(file, pubid_class)
      return nil unless file

      clean_index(file: file, pubid_class: pubid_class)
    end

    def resolve_pubid_class
      begin
        require "pubid"
        Pubid::Easc::Identifier
      rescue LoadError, StandardError
        nil
      end
    end

    # item.id is the dash-separated Latin form (e.g. "rmg-151-2025" or
    # "pmg-v-31-2001"). Pubid::Easc parses the canonical Cyrillic form,
    # so we reconstruct it: <cyrillic-series> [В ]<number>-<year>.
    def add_pubid(idx2, pubid_class, content, rel)
      return unless pubid_class

      parsed = pubid_class.parse(canonical_from_id(content))
      idx2.add_or_update parsed, rel
    rescue StandardError => e
      warn "Skipping #{content} in index-v2: #{e.message}"
    end

    # "rmg-151-2025" → "РМГ 151-2025"
    # "pmg-v-31-2001" → "ПМГ В 31-2001"
    CYR_SERIES = { "pmg" => "ПМГ", "rmg" => "РМГ" }.freeze

    def canonical_from_id(id)
      parts = id.split("-")
      series_latin = parts.shift
      cyr_series = CYR_SERIES.fetch(series_latin) { series_latin.upcase }
      out = cyr_series
      # Optional variant marker
      if parts.first == "v"
        out << " В"
        parts.shift
      end
      number = parts.shift
      year = parts.shift
      out << " #{number}"
      out << "-#{year}" if year
      out
    end
  end
end
