# frozen_string_literal: true

require "pubid"
require "pubid/easc"

module EascFetcher
  # Immutable value object representing an EASC document identifier.
  # Thin wrapper over Pubid::Easc for parse/render/URN concerns.
  class Docid
    attr_reader :series, :variant, :number, :year, :doctype

    def initialize(series:, number:, year: nil, variant: nil, doctype: nil)
      @series = series    # "PMG" | "RMG"
      @variant = variant  # "V" | nil
      @number = number    # "151", "03"
      @year = year        # "2025", "13"
      @doctype = doctype || series_to_doctype(series)
      freeze
    end

    def self.from_string(str)
      id = Pubid::Easc.parse(str)
      new(series: id.series, variant: id.variant, number: id.number, year: id.year)
    end

    def to_s
      pubid.to_s
    end

    # Filesystem-safe stem for data/<stem>.yaml. Lowercase + dash-joined.
    #   "ПМГ В 31-2001" → "pmg-v-31-2001"
    #   "РМГ 151-2025"  → "rmg-151-2025"
    def id
      [
        series&.downcase,
        variant&.downcase,
        number,
        year,
      ].compact.join("-")
    end

    alias filename_stem id

    def urn
      pubid.to_urn
    end

    def ==(other)
      other.is_a?(Docid) &&
        other.series == series &&
        other.variant == variant &&
        other.number == number &&
        other.year == year
    end
    alias eql? ==

    def hash
      [series, variant, number, year].hash
    end

    def pubid
      Pubid::Easc::Identifier.from_hash(
        "_type" => polymorphic_type,
        "series" => series,
        "variant" => variant,
        "number" => number,
        "year" => year,
      )
    end

    private

    def polymorphic_type
      case series
      when "PMG" then "pubid:easc:pmg"
      when "RMG" then "pubid:easc:rmg"
      end
    end

    def series_to_doctype(series)
      case series
      when "PMG" then "pmg"
      when "RMG" then "rmg"
      end
    end
  end
end
