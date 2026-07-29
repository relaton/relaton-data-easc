# frozen_string_literal: true

require "relaton/index"
require "relaton/bib"
require "relaton/easc"
require "fileutils"
require "zip"

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
        add_pubid(idx2, pubid_class, docid.content, rel) if idx2
      rescue StandardError => e
        warn "Error processing #{f}: #{e.message}"
      end

      idx.save
      zip_index(index_file)
      if idx2
        idx2.save
        zip_index(index_v2_file)
      end
      [idx, idx2]
    end

    # Writes <name>.zip next to the YAML, containing the YAML as a single entry
    # stored under its basename — the artifact the relaton read side downloads.
    # Mirrors index-v1.zip across the other relaton-data repos.
    def zip_index(yaml_file)
      zip_file = yaml_file.sub(/\.ya?ml\z/, ".zip")
      raise ArgumentError, "not a YAML index: #{yaml_file}" if zip_file == yaml_file

      entry = File.basename(yaml_file)
      FileUtils.rm_f zip_file
      Zip::File.open(zip_file, Zip::File::CREATE) { |zip| zip.add(entry, yaml_file) }
      zip_file
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

    # `content` is the canonical Cyrillic designation from the item's primary
    # docidentifier (e.g. "РМГ 151-2025" or "ПМГ В 31-2001"), which is exactly
    # the form Pubid::Easc parses.
    def add_pubid(idx2, pubid_class, content, rel)
      return unless pubid_class

      parsed = pubid_class.parse(content)
      idx2.add_or_update parsed, rel
    rescue StandardError => e
      warn "Skipping #{content} in index-v2: #{e.message}"
    end
  end
end
