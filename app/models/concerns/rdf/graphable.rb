# frozen_string_literal: true

module RDF
  module Graphable
    extend ActiveSupport::Concern

    include ActiveSupport::Callbacks
    include Dumpable
    include InferredLanguageTaggable

    PREFIXED_VOCABULARIES = {
      dc: RDF::Vocab::DC11,
      dcterms: RDF::Vocab::DC,
      edm: RDF::Vocab::EDM,
      foaf: RDF::Vocab::FOAF,
      ore: RDF::Vocab::ORE,
      owl: RDF::Vocab::OWL,
      rdaGr2: RDF::Vocab::RDAGR2,
      skos: RDF::Vocab::SKOS,
      wgs84_pos: RDF::Vocab::WGS84_POS
    }.freeze

    class_methods do
      # Set override for the RDF predicate to map a field to.
      #
      # Useful when the RDF predicate can not be deduced from the field name.
      #
      # @example
      #   class EDM::ProvidedCHO
      #     include Mongoid::Document
      #     field :dc_subject_agents, class_name: 'EDM::Agent'
      #     has_rdf_predicate(:dc_subject_agents, RDF::Vocab::DC11.subject)
      #   end
      def has_rdf_predicate(field_name, rdf_predicate)
        rdf_predicates[field_name] = rdf_predicate
      end

      def rdf_predicates
        @rdf_predicates ||= HashWithIndifferentAccess.new
      end

      def rdf_type
        @rdf_type ||= begin
          vocab = RDF::Vocab.const_get(to_s.deconstantize)
          vocab.send(to_s.demodulize)
        end
      end

      def rdf_fields_and_predicates
        @rdf_fields_and_predicates ||= begin
          keys = fields_and_relations.keys
          fields_and_predicates = keys.each_with_object(HashWithIndifferentAccess.new) do |field_name, memo|
            memo[field_name] = rdf_predicate_for_field(field_name)
          end
          fields_and_predicates.reject { |_field_name, rdf_predicate| rdf_predicate.nil? }
        end
      end

      def rdf_predicate_for_field(field_name)
        return rdf_predicates[field_name] if rdf_predicates.key?(field_name)

        PREFIXED_VOCABULARIES.each do |prefix, vocab|
          match = field_name.to_s.match(/\A#{prefix}_(.+)\z/)
          next if match.nil?
          return vocab.respond_to?(match[1]) ? vocab.send(match[1]) : nil
        end
        nil
      end

      def fields_and_relations
        @fields_and_relations ||= fields.merge(relations)
      end
    end

    included do
      attr_accessor :rdf_fields_and_predicates, :rdf_graph
      delegate :fields_and_relations, to: :class
      define_callbacks :graph
    end

    def graph
      self.rdf_fields_and_predicates = self.class.rdf_fields_and_predicates.deep_dup
      run_callbacks :graph do
        self.rdf_graph = to_rdf_graph
      end
      rdf_graph
    end

    def to_rdf
      graph
    end

    def to_rdf_graph
      RDF::Graph.new.tap do |graph|
        graph << [rdf_uri, RDF.type, self.class.rdf_type]
        rdf_fields_and_predicates.each_key do |field_name|
          field = fields_and_relations[field_name]
          field_graph = rdf_graph_for_field(field)
          graph.insert(field_graph) unless field_graph.nil?
        end
      end
    end

    def rdf_graph_for_field(field)
      rdf_predicate = rdf_fields_and_predicates[field.name.to_s]

      if field.is_a?(Mongoid::Fields::Localized)
        rdf_graph_for_localized_field(field, rdf_predicate)
      else
        rdf_graph_for_unlocalized_field(field, rdf_predicate)
      end
    end

    def rdf_graph_for_localized_field(field, rdf_predicate)
      field_value = send("#{field.name}_translations")
      return if field_value.blank?

      RDF::Graph.new.tap do |graph|
        field_value.each_pair do |language, value|
          graph << [rdf_uri, rdf_predicate, rdf_uri_or_literal(value, language: language)]
        end
      end
    end

    def rdf_graph_for_unlocalized_field(field, rdf_predicate)
      field_value = send(field.name)
      return if field_value.blank?

      RDF::Graph.new.tap do |graph|
        [field_value].flatten.each do |value|
          insert_rdf_value_for_unlocalized_field(graph, rdf_predicate, value)
        end
      end
    end

    def insert_rdf_value_for_unlocalized_field(graph, rdf_predicate, value)
      if value.respond_to?(:to_rdf)
        value_rdf = value.to_rdf
        if value_rdf.is_a?(RDF::Literal)
          value_rdf_object = value_rdf
        else
          graph.insert(value_rdf)
        end
      end
      value_rdf_object ||= rdf_uri_or_literal(value, rdf_predicate: rdf_predicate)
      graph << [rdf_uri, rdf_predicate, value_rdf_object]
    end

    # Constructs a UUID URN as an RDF URI, provided the model responds to `#uuid`
    #
    # @return [RDF::URI]
    def rdf_uri
      @rdf_uri ||= begin
        fail "#{self.class} does not respond to :uuid" unless respond_to?(:uuid)
        RDF::URI.new("urn:uuid:#{uuid}")
      end
    end

    def rdf_uri_or_literal(value, language: nil, rdf_predicate: nil)
      return value.rdf_uri if value.respond_to?(:rdf_uri)

      uri = begin
        ::URI.parse(value)
      rescue ::URI::InvalidURIError
        nil
      end

      return RDF::URI.new(uri) unless uri&.scheme.nil?

      language ||= infer_rdf_language_tag(on: rdf_predicate)

      language.nil? ? value : RDF::Literal.new(value, language: language)
    end

    def rewrite_rdf_graph_statements
      deletes = []
      inserts = []

      rdf_graph.each_statement do |statement|
        statement_was = statement.dup
        yield statement
        unless statement == statement_was
          deletes.push(statement_was)
          inserts.push(statement)
        end
      end

      rdf_graph.delete_insert(deletes, inserts)
    end
  end
end
