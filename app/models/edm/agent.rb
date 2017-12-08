# frozen_string_literal: true

module EDM
  class Agent
    include Mongoid::Document
    include RDFModel

    embedded_in :dc_creator_for, class_name: 'EDM::ProvidedCHO', inverse_of: :dc_creator
    embedded_in :dc_contributor_for, class_name: 'EDM::ProvidedCHO', inverse_of: :dc_contributor

    belongs_to :rdaGr2_placeOfBirth, class_name: 'EDM::Place', optional: true
    belongs_to :rdaGr2_placeOfDeath, class_name: 'EDM::Place', optional: true

    field :rdaGr2_dateOfBirth, type: Date
    field :rdaGr2_dateOfDeath, type: Date
    field :skos_prefLabel, type: Hash
    field :skos_altLabel, type: Hash
    field :foaf_name, type: String

    rails_admin do
      visible false
      object_label_method { :foaf_name }
      field :foaf_name, :string
      field :rdaGr2_dateOfBirth
      # field :rdaGr2_placeOfBirth
      field :rdaGr2_dateOfDeath
      # field :rdaGr2_placeOfDeath
    end

    def blank?
      attributes.except('_id').values.all?(&:blank?) &&
        rdaGr2_placeOfBirth.blank? &&
        rdaGr2_placeOfDeath.blank?
    end

    def to_rdf
      RDF::Graph.new.tap do |graph|
        graph << [rdf_uri, RDF.type, RDF::Vocab::EDM.Agent]
        graph << [rdf_uri, RDF::Vocab::FOAF.name, foaf_name] unless foaf_name.blank?
      end
    end
  end
end