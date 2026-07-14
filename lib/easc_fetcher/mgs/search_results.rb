# frozen_string_literal: true

require "nokogiri"

module EascFetcher
  module Mgs
    # Parses the mgscatalog.by search.ajax.php response HTML into
    # summary records. Each search result row corresponds to one
    # EASC document.
    class SearchResults
      Summary = Struct.new(
        :doc_id,         # "478357"
        :designation,    # "РМГ 151-2025"
        :title,          # "Введение в действие..."
        :status,         # "Введен впервые"
        :detail_url,     # "/katalogstand_detail.php?UrlRN=478357"
        keyword_init: true,
      )

      Result = Struct.new(:items, :total, :last_page, keyword_init: true)

      PER_PAGE = 11

      def self.parse(html)
        new(html).parse
      end

      def initialize(html)
        @doc = Nokogiri::HTML(html.to_s, nil, "UTF-8")
      end

      def parse
        Result.new(items: items, total: total_count, last_page: last_page)
      end

      private

      def items
        @doc.css("table tbody tr").map do |tr|
          tds = tr.css("td")
          next nil if tds.size < 2

          link = tr.at_css("a[href*='katalogstand_detail']")
          detail_url = link && link["href"]
          doc_id = detail_url && detail_url[/UrlRN=(\d+)/, 1]

          Summary.new(
            doc_id: doc_id,
            designation: text_at(tds[0]),
            title: text_at(tds[1]),
            status: tds[2] ? text_at(tds[2]) : nil,
            detail_url: detail_url,
          )
        end.compact
      end

      def total_count
        m = @doc.at_css("body").to_html.match(/Документов найдено:\s*<span[^>]*>([\d]+)/)
        m ? m[1].to_i : 0
      end

      def last_page
        return 1 if total_count.zero?

        (total_count / PER_PAGE.to_f).ceil
      end

      def text_at(node)
        return nil unless node

        text = node.text.to_s.strip
        text.empty? ? nil : text
      end
    end
  end
end
