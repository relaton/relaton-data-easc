# frozen_string_literal: true

module EascFetcher
  # Common base type for every entry yielded by a Source. Each entry
  # knows how to build its own Docid (polymorphism) and carries the
  # extra mgscatalog.by metadata harvested from the detail page:
  # session, developer, joining_states, assigned_to.
  class SourceEntry
    attr_reader :series, :variant, :number, :year, :title,
                :web_url, :status,
                :session, :developer, :joining_states, :assigned_to

    def initialize(series:, number:, year: nil, variant: nil, title: nil,
                   web_url: nil, status: nil,
                   session: nil, developer: nil, joining_states: nil,
                   assigned_to: nil)
      @series          = series
      @variant         = variant
      @number          = number
      @year            = year
      @title           = title
      @web_url         = web_url
      @status          = status
      @session         = session
      @developer       = developer
      @joining_states  = Array(joining_states)
      @assigned_to     = assigned_to
    end

    def to_docid
      EascFetcher::Docid.new(
        series: series, number: number, year: year, variant: variant,
      )
    end
  end
end
