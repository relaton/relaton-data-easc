# frozen_string_literal: true

require "date"
require "fileutils"

module EascFetcher
  # Orchestrates source → YAML emission for EASC documents.
  class PublicationFetcher
    attr_reader :data_dir, :yaml_store, :sources

    def initialize(data_dir:, yaml_store:, sources:)
      @data_dir = data_dir
      @yaml_store = yaml_store
      @sources = Array(sources)
    end

    def run
      FileUtils.mkdir_p(@data_dir)
      @sources.each { |s| emit_from_source(s) }
    end

    private

    def emit_from_source(source)
      source.each_entry do |entry|
        emit_entry(entry)
      rescue StandardError => e
        warn "  ERROR emitting #{entry.inspect}: #{e.message}"
      end
    end

    def emit_entry(entry)
      docid = entry.to_docid
      hash = build_hash(entry, docid)
      yaml_store.write(docid.filename_stem, hash)
    end

    def build_hash(entry, docid)
      title_text = entry.title || docid.to_s
      date = year_to_date(docid.year)

      hash = {
        "id" => docid.id,
        "type" => "standard",
        "title" => [{
          "language" => "rus",
          "content" => title_text,
          "type" => "main",
        }],
        "docidentifier" => [{
          "content" => docid.to_s,
          "type" => "EASC",
          "primary" => true,
        }],
        "docnumber" => docid.number,
        "contributor" => contributors_for(entry),
        "language" => ["rus"],
        "script" => ["Cyrl"],
        "status" => { "stage" => { "content" => (entry.status || "in-force") } },
        "ext" => ext_block(entry, docid),
      }
      apply_dates!(hash, date)
      apply_copyright!(hash, date)
      hash
    end

    def contributors_for(entry)
      list = [EascFetcher.easc_publisher_contributor]
      return list unless entry.developer && !entry.developer.empty?

      list << {
        "role" => [{ "type" => "author" }],
        "organization" => { "name" => [{ "content" => entry.developer }] },
      }
      list
    end

    def ext_block(entry, docid)
      ext = {
        "doctype" => { "content" => docid.doctype },
        "flavor" => "easc",
      }
      ext["urn"] = docid.urn
      ext["webpage"] = entry.web_url if entry.web_url
      ext["session"] = entry.session if entry.session
      ext["developer"] = entry.developer if entry.developer
      if entry.joining_states.any?
        ext["joining_states"] = entry.joining_states.map { |s| { "content" => s } }
      end
      ext["assigned_to"] = entry.assigned_to if entry.assigned_to
      ext
    end

    def year_to_date(year)
      return nil unless year

      y = year.to_i
      y += 1900 if y < 100 && y >= 30
      y += 2000 if y < 30
      Date.new(y, 1, 1)
    rescue ArgumentError
      nil
    end

    def apply_dates!(hash, date)
      return unless date

      hash["date"] = [{ "type" => "published", "from" => date.iso8601 }]
    end

    def apply_copyright!(hash, date)
      return unless date

      hash["copyright"] = [{
        "from" => date.year.to_s,
        "owner" => [{ "organization" => EascFetcher.easc_org_hash }],
      }]
    end
  end
end
