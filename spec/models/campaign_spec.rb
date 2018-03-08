# frozen_string_literal: true

RSpec.describe Campaign do
  subject { create(:campaign) }

  describe 'class' do
    subject { described_class }
    it { is_expected.to include(Mongoid::Document) }
    it { is_expected.to include(Mongoid::Timestamps) }
  end

  describe 'relations' do
    it {
      is_expected.to have_many(:contributions).of_type(Contribution).
        as_inverse_of(:campaign).with_dependent(:restrict)
    }
  end

  it { should validate_presence_of(:dc_identifier) }
  it { should validate_uniqueness_of(:dc_identifier) }

  describe '#rdf_uri' do
    it 'uses base URL, /campaigns/ and dc_identifier' do
      Rails.configuration.x.base_url = 'http://example.org'
      campaign = Campaign.new(dc_identifier: 'folk-music')
      expect(campaign.rdf_uri).to be_a(RDF::URI)
      expect(campaign.rdf_uri.to_s).to eq('http://example.org/campaigns/folk-music')
    end
  end
end
