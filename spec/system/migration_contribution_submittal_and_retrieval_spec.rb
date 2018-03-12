# frozen_string_literal: true

# These tests make use of the whole stack including redis through sidekiq.
# In order to properly adapt/inspect jobs/data queued/generated by sidekiq,
# 'sidekiq/testing' and 'sidekiq/api' need to be included.
require 'sidekiq/testing'
require 'sidekiq/api'

require 'support/shared_contexts/campaigns/migration'

RSpec.describe 'Migration contribution submittal and retrieval', sidekiq: true do
  include_context 'migration campaign'

  before do
    # TODO: When form saving is fully functional consider enabling it here
    ENV['ENABLE_JS_FORM_SAVE'] = 'false'
  end

  %w(true false).each do |js_form_validation|
    context "when ENV['ENABLE_JS_FORM_VALIDATION'] = '#{js_form_validation}'" do
      before do
        ENV['ENABLE_JS_FORM_VALIDATION'] = js_form_validation
      end

      it 'takes a submission and generates thumbnails', type: :system, js: true do
        existing_aggregation = ORE::Aggregation.last

        visit new_migration_url

        sleep 2

        expect(URI.parse(page.current_url).path).to eq(URI.parse(new_migration_url).path)

        inputs = {
          contribution_ore_aggregation_edm_isShownBy_media: proc {
            attach_file('Object 1', Rails.root + 'spec/support/media/image.jpg')
            choose('contribution[ore_aggregation_attributes][edm_isShownBy_attributes][edm_rights_id]', option: CC::License.first.id.to_s, visible: false)
          },
          contribution_ore_aggregation_edm_aggregatedCHO_dc_contributor_agent_foaf_name: proc { fill_in('Your name', with: 'Tester One') },
          contribution_age_confirm: proc { check('I am over 16 years old') },
          contribution_ore_aggregation_edm_aggregatedCHO_dc_contributor_agent_skos_prefLabel: proc { fill_in('Public display name', with: 'Tester Public') },
          contribution_ore_aggregation_edm_aggregatedCHO_dc_contributor_agent_foaf_mbox: proc { fill_in('Your email address', with: 'tester@europeana.eu') },
          contribution_ore_aggregation_edm_aggregatedCHO_dc_title: proc { fill_in('Give your story a title', with: 'Test Contribution') },
          contribution_ore_aggregation_edm_aggregatedCHO_dc_description: proc { fill_in('Tell or describe your story', with: 'Test test test.') },
          contribution_content_policy_accept: proc { check('contribution_content_policy_accept') },
          contribution_display_and_takedown_accept: proc { check('contribution_display_and_takedown_accept') }
        }

        # Fill in one input at a time and submit, expecting failure until all filled in
        # TODO: check every permutation of inputs filled in or not for failure unless
        #   all are?
        inputs.each_pair do |class_selector, input|
          input.call
          find('input[name="commit"]').click

          if class_selector != inputs.keys.last
            expected_path = js_form_validation == 'true' ? URI.parse(new_migration_url).path : URI.parse(migration_index_url).path
            expect(URI.parse(page.current_url).path).to eq(expected_path)

            expect(page).not_to have_content(I18n.t('contribute.campaigns.migration.pages.create.flash.success'))

            # Check that all other inputs have error messages
            # Except last one when JS form validation is enabled.
            # TODO: cover the last one when JS form validation is enabled too
            subsequent_key_range = (inputs.keys.index(class_selector) + 1)..-1
            subsequent_class_selectors = inputs.keys[subsequent_key_range]
            subsequent_class_selectors.each do |subsequent_class_selector|
              css_selector = "div.#{subsequent_class_selector} span.error"
              expect(page).to have_css(css_selector),
                %(having completed inputs up to "#{class_selector}", expected to find visible css "#{css_selector}" but there were no matches)
            end
          else
            expect(URI.parse(page.current_url).path).to eq(URI.parse(migration_index_url).path)
            expect(page).to have_content(I18n.t('contribute.campaigns.migration.pages.create.flash.success'))
          end
        end

        # Find the submission
        aggregation = ORE::Aggregation.last

        # Make sure it's a newly created aggregation.
        expect(aggregation).to_not eq(existing_aggregation)

        # Check the CHO attributes.
        aggregatedCHO = aggregation.edm_aggregatedCHO
        expect(aggregatedCHO.dc_title).to include('Test Contribution')
        expect(aggregatedCHO.dc_description).to include('Test test test.')
        expect(aggregatedCHO.edm_type).to eq('IMAGE')

        # Check the contributor attributes.
        dc_contributor = aggregatedCHO.dc_contributor_agent
        expect(dc_contributor).not_to be_nil
        expect(dc_contributor.foaf_mbox).to include('tester@europeana.eu')

        # Ensure all thumbnailJobs have been picked up
        timeout = 20
        queue = Sidekiq::Queue.new('thumbnails')
        while queue.size.nonzero?
          sleep 1
          timeout -= 1
          fail('Waited too long to process thumbnail jobs.') if timeout.zero?
        end

        webresource = aggregation.edm_isShownBy

        # Check for thumbnails
        [200, 400].each do |dimension|
          thumb_sym = "w#{dimension}".to_sym
          thumbnail_url =  webresource.media.url(thumb_sym)

          # Ensure thumbnail is retrievable over http.
          timeout = 20
          response = nil
          while response&.status != 200
            sleep 1
            timeout -= 1
            response = Faraday.get(thumbnail_url)
            fail("Waited too long before thumbnail was http accessible. #{thumbnail_url}") if timeout.zero?
          end
          expect(response['content-type']).to eq('image/jpeg')

          # Check image attributes using MiniMagick
          img = MiniMagick::Image.open(thumbnail_url)
          expect(img.mime_type).to eq('image/jpeg')
          expect(img.dimensions).to eq([dimension, dimension])
        end
      end
    end
  end
end
