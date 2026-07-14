# frozen_string_literal: true

require "thor"

module EascFetcher
  class Scrape < Thor
    def self.exit_on_failure? = true

    default_task :fetch

    desc "fetch", "Fetch EASC documents from mgscatalog.by into data/"
    method_option :series, type: :string, repeatable: true,
                            desc: "EASC series to fetch (pmg, rmg). Defaults to both."
    method_option :limit, type: :numeric, default: nil,
                          desc: "Cap items per series. Useful for test runs."
    method_option :delay, type: :numeric, default: 1.0,
                          desc: "Polite delay between mgscatalog.by requests (seconds)."
    method_option :cache_dir, type: :string, default: "sources/mgs-cache",
                              desc: "Where to cache mgscatalog.by HTML responses."
    method_option :data_dir, type: :string, default: "data"
    def fetch
      source = build_source(options.to_h)
      store = EascFetcher::YamlStore.new(options[:data_dir])
      say "Fetching EASC documents (series=#{source.series.inspect}, delay=#{options[:delay]})", :cyan

      EascFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir],
        yaml_store: store,
        sources: [source],
      ).run

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "index", "Rebuild index-v1.yaml + index-v2.yaml from data/*.yaml"
    def index
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    private

    def build_source(opts)
      series = Array(opts[:series]).map(&:to_s)
      series = EascFetcher::Sources::Mgscatalog::SERIES.keys if series.empty?

      client = EascFetcher::Mgs::Client.new(
        delay: opts[:delay],
        cache_dir: opts[:cache_dir],
      )

      EascFetcher::Sources::Mgscatalog.new(
        series: series,
        client: client,
        per_series_limit: opts[:limit],
      )
    end
  end
end
