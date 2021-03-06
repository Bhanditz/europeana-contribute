# frozen_string_literal: true

FactoryBot.define do
  factory :contribution, class: Contribution do
    campaign
    ore_aggregation
    age_confirm true
    content_policy_accept true
    display_and_takedown_accept true
    trait :published do
      aasm_state 'published'
      ore_aggregation { build(:ore_aggregation, :published) }
      first_published_at Forgery::Date.date
    end
    trait :deleted do
      aasm_state 'deleted'
      ore_aggregation nil
      first_published_at Forgery::Date.date
      oai_pmh_record_id SecureRandom.uuid
    end
  end
end
