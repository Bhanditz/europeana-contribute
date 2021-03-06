# frozen_string_literal: true

FactoryBot.define do
  factory :edm_event, class: EDM::Event do
    skos_prefLabel { |n| "Event #{n}" }
  end
end
