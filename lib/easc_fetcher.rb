# frozen_string_literal: true

require "relaton/bib"
require "relaton/easc"

# EascFetcher scrapes mgscatalog.by for EASC (ПМГ, РМГ) documents into
# Relaton YAML files under data/.
module EascFetcher
  BASE_URL = "https://mgscatalog.by".freeze

  EASC_NAME = "Eurasian Economic Standards Council".freeze
  EASC_ABBR = "EASC".freeze

  DOCTYPES = {
    "pmg" => { title: "Interstate Rules",            series: "PMG" },
    "rmg" => { title: "Interstate Recommendations",  series: "RMG" },
  }.freeze

  def self.easc_org_hash
    {
      "name" => [{ "content" => EASC_NAME }],
      "abbreviation" => { "content" => EASC_ABBR },
    }
  end

  def self.easc_publisher_contributor
    {
      "role" => [{ "type" => "publisher" }],
      "organization" => easc_org_hash,
    }
  end

  autoload :Docid,              "easc_fetcher/docid"
  autoload :Source,             "easc_fetcher/source"
  autoload :SourceEntry,        "easc_fetcher/source_entry"
  autoload :Http,               "easc_fetcher/http"
  autoload :YamlStore,          "easc_fetcher/yaml_store"
  autoload :PublicationFetcher, "easc_fetcher/publication_fetcher"
  autoload :Indexer,            "easc_fetcher/indexer"
  autoload :Scrape,             "easc_fetcher/scrape"

  module Mgs
    autoload :Client,         "easc_fetcher/mgs/client"
    autoload :SearchResults,  "easc_fetcher/mgs/search_results"
    autoload :DocumentPage,   "easc_fetcher/mgs/document_page"
  end

  module Sources
    autoload :Base,        "easc_fetcher/sources/base"
    autoload :Mgscatalog,  "easc_fetcher/sources/mgscatalog"
  end
end
