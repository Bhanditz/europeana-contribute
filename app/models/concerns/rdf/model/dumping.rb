# frozen_string_literal: true

module RDF
  module Model
    # Including classes are expected to implement `#to_rdf` to return an
    # `RDF::Graph`.
    module Dumping
      extend ActiveSupport::Concern

      def to_jsonld(**options)
        to_rdf.dump(:jsonld, options.reverse_merge(prefixes: Model::NAMESPACE_PREFIXES.dup))
      end

      def to_turtle(**options)
        to_rdf.dump(:turtle, options.reverse_merge(prefixes: Model::NAMESPACE_PREFIXES.dup))
      end

      def to_ntriples(**options)
        to_rdf.dump(:ntriples, options.reverse_merge(prefixes: Model::NAMESPACE_PREFIXES.dup))
      end

      def to_rdfxml(**options)
        rdfxml_default_options = {
          prefixes: Model::NAMESPACE_PREFIXES.dup,
          max_depth: 0,
          haml_options: { format: :xhtml, attr_wrapper: '"' }
        }

        to_rdf.dump(:rdfxml, options.reverse_merge(rdfxml_default_options))
      end

      def to_oai_edm
        to_rdfxml.sub(/<\?xml .*? ?>/, '').strip
      end
    end
  end
end
