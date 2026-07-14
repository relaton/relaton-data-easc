# frozen_string_literal: true

module EascFetcher
  class Source
    def self.url(url)
      { "type" => "website", "content" => url }
    end

    def self.mgs(path)
      return url(path) if path.to_s.start_with?("http")

      base = EascFetcher::BASE_URL.chomp("/")
      path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
      url("#{base}#{path}")
    end

    def self.webpage(url)
      { "type" => "website", "content" => url }
    end

    def self.local(path)
      { "type" => "file", "content" => path }
    end
  end
end
