#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "relaton/index"
require "relaton/bib"
require "easc_fetcher"

EascFetcher::Indexer.build(
  data_dir: "data",
  index_file: "index-v1.yaml",
  index_v2_file: "index-v2.yaml",
)
