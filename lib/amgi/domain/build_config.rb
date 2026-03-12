# frozen_string_literal: true

module Amgi
  module Domain
    class BuildConfig
      attr_reader :schema, :name, :note_schema, :global_tags, :cards, :css

      def initialize(attributes)
        @schema = attributes.fetch(:schema)
        @name = attributes.fetch(:name)
        @note_schema = attributes.fetch(:note_schema)
        @global_tags = attributes.fetch(:global_tags)
        @cards = attributes.fetch(:cards)
        @css = attributes[:css]
      end

      def required_fields
        note_schema.required_fields
      end

      def optional_fields
        note_schema.optional_fields
      end

      def all_fields
        note_schema.all_fields
      end

      def default_cards
        cards.select(&:default?)
      end

      def card_ids
        cards.map(&:id)
      end
    end
  end
end
