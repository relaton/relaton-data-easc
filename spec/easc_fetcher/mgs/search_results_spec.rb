# frozen_string_literal: true

require "spec_helper"

RSpec.describe EascFetcher::Mgs::SearchResults do
  # Build a synthetic search-result HTML sample that mirrors
  # mgscatalog.by's actual output structure.
  let(:html) do
    <<~HTML
      <html><body>
      <div>Документов найдено: <span style="font-weight:bold;">2</span>.</div>
      <table class="sort table">
        <thead><tr><th>Обозначение</th><th>Наименование</th><th>Состояние</th></tr></thead>
        <tbody>
          <tr>
            <td><a href="katalogstand_detail.php?UrlRN=478357">РМГ 151-2025</a></td>
            <td>Введение в действие...</td>
            <td>Введен впервые</td>
          </tr>
          <tr>
            <td><a href="katalogstand_detail.php?UrlRN=477360">РМГ 150-2023</a></td>
            <td>Государственная система обеспечения единства измерений. Весы...</td>
            <td>Введен впервые</td>
          </tr>
        </tbody>
      </table>
      </body></html>
    HTML
  end

  it "extracts every result row" do
    result = described_class.parse(html)
    expect(result.items.size).to eq(2)
  end

  it "captures doc_id, designation, status" do
    first = described_class.parse(html).items.first
    expect(first.doc_id).to eq("478357")
    expect(first.designation).to eq("РМГ 151-2025")
    expect(first.status).to eq("Введен впервые")
    expect(first.detail_url).to eq("katalogstand_detail.php?UrlRN=478357")
  end

  it "reports total and last_page" do
    result = described_class.parse(html)
    expect(result.total).to eq(2)
    expect(result.last_page).to eq(1)
  end
end
