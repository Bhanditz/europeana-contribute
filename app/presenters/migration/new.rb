# frozen_string_literal: true

module Migration
  class New < ApplicationPresenter
    def content
      mustache[:content] ||= begin
        {
          title: page_content_heading,
          text: errors + aggregation_form
        }
      end
    end

    def page_content_heading
      'Tell your story'
    end

    protected

    def errors
      return '' unless flash[:error].present?
      flash[:error].join('<br>')
    end

    def aggregation_form
      simple_form_for @aggregation, url: { action: 'create' } do |f|
        f.simple_fields_for(:edm_isShownBy) do |wr|
          wr.input(:media)
        end +
          f.simple_fields_for(:edm_aggregatedCHO) do |cho|
            cho.input(:dc_title, label: 'Define a title for this item') +
              cho.input(:dc_language, collection: EDM::ProvidedCHO.dc_language_enum, label: 'What is the language of the text in this item?') +
              cho.input(:dc_description, as: :text, input_html: { rows: 10 }, label: 'Tell us the story of this object - including a description') +
              cho.input(:edm_type, collection: EDM::ProvidedCHO.edm_type_enum) +
              cho.simple_fields_for(:dc_contributor) do |contributor|
                contributor.input(:foaf_name, label: "What's your name?")
              end +
              cho.simple_fields_for(:dc_creator) do |creator|
                creator.input(:foaf_name, label: 'Who created this item?') # +
                # creator.input(:rdaGr2_dateOfBirth, as: :date) +
                # creator.input(:rdaGr2_dateOfDeath, as: :date)
              end +
              cho.input(:dcterms_created, as: :date, html5: true, label: 'When was the item created?') +
              cho.input(:edm_currentLocation, label: 'Where is the item currently located?')
          end +
          f.input(:edm_rights, collection: CC::License.all.map { |l| [l.rdf_about, l.id] }) +
          f.button(:submit, 'Submit', class: 'inline-form-button')
      end
    end
  end
end