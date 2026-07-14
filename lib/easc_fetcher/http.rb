# frozen_string_literal: true

require "net/http"

module EascFetcher
  module Http
    class Error < StandardError; end
    class TooManyRedirects < Error; end
    class BadStatus < Error; end
    class Timeout < Error; end

    class << self
      attr_accessor :backend
    end

    class NetHttp
      def get(url, redirects: 5, read_timeout: 30, open_timeout: 15, headers: {})
        uri = URI(url)
        fetch_with_redirects(uri, redirects, read_timeout, open_timeout, 0, headers)
      end

      private

      def fetch_with_redirects(uri, max, read_timeout, open_timeout, depth, headers)
        raise EascFetcher::Http::TooManyRedirects, uri.to_s if depth >= max

        http = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == "https",
                               read_timeout: read_timeout,
                               open_timeout: open_timeout)
        req = Net::HTTP::Get.new(uri.request_uri, headers)
        res = http.request(req)
        case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection
          location = res["location"]
          next_uri = location.start_with?("http") ? URI(location) : uri.merge(location)
          fetch_with_redirects(next_uri, max, read_timeout, open_timeout, depth + 1, headers)
        else
          raise EascFetcher::Http::BadStatus, "HTTP #{res.code} for #{uri}"
        end
      rescue Net::ReadTimeout, Net::OpenTimeout
        raise EascFetcher::Http::Timeout, uri.to_s
      end
    end

    class Fake
      def initialize(table = {})
        @table = table
      end

      def get(url, **_); entry = @table[url]; entry.is_a?(Proc) ? entry.call(url) : entry; end
    end

    self.backend = NetHttp.new
  end
end
