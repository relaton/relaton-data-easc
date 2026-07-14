# frozen_string_literal: true

require "nokogiri"

module EascFetcher
  module Mgs
    # Parses a mgscatalog.by document detail page
    # (/katalogstand_detail.php?UrlRN=<id>) into a metadata record.
    #
    # The detail page is a simple <table> with label/value rows.
    # Selectors target the .table-responsive table cells.
    class DocumentPage
      Result = Struct.new(
        :doc_id, :designation, :title, :scope,
        :adoption_info, :category, :status,
        :replaces, :developer, :assigned_to,
        :joining_states,
        keyword_init: true,
      )

      # Russian status terms → English equivalents used in
      # status.stage.content.
      STATUS_MAP = {
        "Введен впервые"     => "new",
        "Введена впервые"    => "new",
        "Взамен"             => "replaces",
        "Отменен"            => "withdrawn",
        "Отменён"            => "withdrawn",
        "Заменен"            => "replaced",
        "Заменён"            => "replaced",
        "Действует"          => "active",
        "Введен"             => "active",
      }.freeze

      def self.parse(html, doc_id: nil)
        new(html, doc_id: doc_id).parse
      end

      def initialize(html, doc_id: nil)
        @doc = Nokogiri::HTML(html.to_s, nil, "UTF-8")
        @doc_id = doc_id
      end

      def parse
        meta = parse_meta_grid

        Result.new(
          doc_id:          @doc_id,
          designation:     meta["Обозначение"],
          title:           meta["Наименование"],
          scope:           meta["Область применения"],
          adoption_info:   meta["Информация о принятии"],
          category:        meta["Категория"],
          status:          mapped_status(meta["Состояние"]),
          replaces:        meta["Заменённые"],
          developer:       meta["Разработчик"] || meta_value_stripped("Разработчик "),
          assigned_to:     meta["Закреплен за "],
          joining_states:  joining_states,
        )
      end

      private

      # Build {label => value} hash from the table rows. Each row has
      # two <td>s: the label (with <b>) and the value.
      def parse_meta_grid
        @doc.css("table tr").each_with_object({}) do |tr, acc|
          tds = tr.css("td")
          next if tds.size < 2

          label = label_text(tds[0])
          value = value_text(tds[1])
          acc[label] = value if label && value
        end
      end

      def label_text(td)
        text = td.text.to_s.strip
        text.empty? ? nil : text
      end

      def value_text(td)
        # If the cell contains <br />, join lines with ", " (used for
        # joining_states list). Otherwise return as a single string.
        text = td.inner_html.to_s
        if text.include?("<br")
          td.css("br").each { |br| br.add_previous_sibling(Nokogiri::XML::Text.new(", ", br.document)) }
          joined = td.text.to_s.split(/,\s*/).map(&:strip).reject(&:empty?)
          return joined.size > 1 ? joined : joined.first
        end

        text = td.text.to_s.strip
        text.empty? ? nil : text
      end

      def meta_value_stripped(label)
        # Some labels have trailing whitespace ("Разработчик ").
        # parse_meta_grid already handles this via the canonical label.
        nil
      end

      def joining_states
        # Find the row with "Присоединившиеся государства" label and
        # extract each <br />-separated value. Iterate over cell
        # children to avoid string-splitting HTML quirks.
        row = @doc.css("table tr").find do |tr|
          tr.at_css("td b")&.text&.strip == "Присоединившиеся государства"
        end
        return [] unless row

        tds = row.css("td")
        return [] unless tds.size >= 2

        value_cell = tds[1]
        value_cell.children.map do |node|
          next nil if node.is_a?(Nokogiri::XML::Element) && node.name == "br"

          text = node.text.to_s.strip
          text.empty? ? nil : text
        end.compact
      end

      def mapped_status(raw)
        return nil unless raw

        STATUS_MAP[raw] || raw
      end
    end
  end
end
