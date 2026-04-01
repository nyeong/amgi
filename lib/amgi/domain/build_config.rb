# frozen_string_literal: true

module Amgi
  module Domain
    class BuildConfig
      BLANK_FIELD_SUFFIX = 'Blank'

      attr_reader :schema, :name, :note_schema, :global_tags, :cards, :css, :output

      def initialize(attributes)
        @schema = attributes.fetch(:schema)
        @name = attributes.fetch(:name)
        @note_schema = attributes.fetch(:note_schema)
        @global_tags = attributes.fetch(:global_tags)
        @cards = attributes.fetch(:cards)
        @css = attributes[:css]
        @output = attributes[:output]
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

      def derived_blank_fields
        @derived_blank_fields ||= all_fields.select do |field|
          field.end_with?(BLANK_FIELD_SUFFIX) && all_fields.include?(base_field_for_blank(field))
        end
      end

      def derived_blank_field?(field)
        derived_blank_fields.include?(field)
      end

      def blank_source_field?(field)
        all_fields.include?(derived_blank_field_name(field))
      end

      def derived_blank_field_name(field)
        "#{field}#{BLANK_FIELD_SUFFIX}"
      end

      def base_field_for_blank(field)
        field.delete_suffix(BLANK_FIELD_SUFFIX)
      end
    end
  end
end
