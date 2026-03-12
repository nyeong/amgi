# frozen_string_literal: true

module Amgi
  module Domain
    class BuildConfig
      attr_reader :schema, :name, :required_fields, :optional_fields, :global_tags, :templates

      def initialize(schema:, name:, required_fields:, optional_fields:, global_tags:, templates:)
        @schema = schema
        @name = name
        @required_fields = required_fields
        @optional_fields = optional_fields
        @global_tags = global_tags
        @templates = templates
      end

      def all_fields
        @all_fields ||= required_fields + optional_fields
      end
    end
  end
end
