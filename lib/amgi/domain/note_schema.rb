# frozen_string_literal: true

module Amgi
  module Domain
    class NoteSchema
      PLACEHOLDER_PATTERN = /{{\s*([A-Za-z][A-Za-z0-9_]*)\s*}}/

      attr_reader :id, :required_fields, :optional_fields

      def initialize(id:, required_fields:, optional_fields:)
        @id = id
        @required_fields = required_fields
        @optional_fields = optional_fields
      end

      def all_fields
        @all_fields ||= required_fields + optional_fields
      end

      def id_fields
        @id_fields ||= id.to_s.scan(PLACEHOLDER_PATTERN).flatten.uniq
      end

      def render_id(note)
        id.to_s.gsub(PLACEHOLDER_PATTERN) do
          note[Regexp.last_match(1)].to_s
        end
      end
    end
  end
end
