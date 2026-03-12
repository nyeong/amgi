# frozen_string_literal: true

module Amgi
  module Domain
    class NoteSchema
      attr_reader :required_fields, :optional_fields

      def initialize(required_fields:, optional_fields:)
        @required_fields = required_fields
        @optional_fields = optional_fields
      end

      def all_fields
        @all_fields ||= required_fields + optional_fields
      end
    end
  end
end
