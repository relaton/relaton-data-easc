# frozen_string_literal: true

require "fileutils"
require "digest"

module EascFetcher
  module Mgs
    # Polite HTTP client for mgscatalog.by. Disk-cache by URL SHA1,
    # polite delay, exponential backoff on 5xx. Mirrors the KSM
    # client's shape but is mgscatalog.by-specific (different host,
    # different cache layout).
    class Client
      HOST = "https://mgscatalog.by".freeze
      DEFAULT_DELAY = 1.0
      DEFAULT_CACHE_DIR = "sources/mgs-cache".freeze

      attr_reader :cache_dir, :delay, :http_backend

      def initialize(cache_dir: nil, delay: nil,
                     http_backend: EascFetcher::Http.backend)
        @cache_dir = File.expand_path(cache_dir || DEFAULT_CACHE_DIR)
        @delay = (delay || DEFAULT_DELAY).to_f
        @http_backend = http_backend
        FileUtils.mkdir_p(@cache_dir)
        @last_request_at = 0.0
      end

      def get(path, body: nil)
        url = absolute_url(path)
        cache_payload = body ? "#{url}?#{URI.encode_www_form(body)}" : url
        key = cache_key(cache_payload)
        cached = read_cache(key)
        return cached if cached

        throttle!
        response = fetch_with_retry(url, body)
        return response unless response && !response.empty?

        write_cache(key, url, response)
        response
      end

      private

      def absolute_url(path)
        return path if path.start_with?("http")

        "#{HOST}#{path.start_with?("/") ? path : "/#{path}"}"
      end

      def cache_key(payload)
        Digest::SHA1.hexdigest(payload)
      end

      def read_cache(key)
        path = File.join(@cache_dir, "#{key}.html")
        return nil unless File.exist?(path) && File.size(path).positive?

        File.read(path, encoding: "UTF-8")
      end

      def write_cache(key, url, body)
        utf8 = body.to_s.dup.force_encoding("UTF-8")
        File.write(File.join(@cache_dir, "#{key}.html"), utf8, encoding: "UTF-8")
        File.write(File.join(@cache_dir, "#{key}.url"), url, encoding: "UTF-8")
      rescue StandardError
        # Cache-write failure shouldn't crash the scrape.
      end

      def throttle!
        return if @delay <= 0

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at
        sleep(@delay - elapsed) if elapsed < @delay
        @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def fetch_with_retry(url, body, attempts: 4)
        delay = 30
        attempts.times do |n|
          return body ? http_post(url, body) : http_backend.get(url)
        rescue EascFetcher::Http::BadStatus => e
          raise if n == attempts - 1
          raise unless e.message.match?(/HTTP (429|5\d\d)/)

          warn "  MGS #{e.message}; retry in #{delay}s (attempt #{n + 1}/#{attempts})"
          sleep delay
          delay = [delay * 2, 300].min
        end
      end

      def http_post(url, form_body)
        require "net/http"
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = 30
        req = Net::HTTP::Post.new(uri.request_uri).tap do |r|
          r.set_form_data(form_body)
          r["X-Requested-With"] = "XMLHttpRequest"
        end
        res = http.request(req)
        unless res.is_a?(Net::HTTPSuccess)
          raise EascFetcher::Http::BadStatus, "HTTP #{res.code} for #{uri}"
        end

        res.body.to_s.dup.force_encoding("UTF-8")
      end
    end
  end
end
