# frozen_string_literal: true

module Amgi
  module Domain
    class Template
      PLACEHOLDER_PATTERN = /{{\s*([A-Za-z][A-Za-z0-9_]*)\s*}}/
      ALLOWED_TEMPLATE_TOKENS = %w[FrontSide].freeze

      attr_reader :name, :front, :back

      def initialize(name:, front:, back:, default: false)
        @name = name
        @front = front
        @back = back
        @default = default
      end

      def default?
        @default
      end

      def front_fields
        referenced_fields(front)
      end

      private

      def referenced_fields(body)
        body.to_s.scan(PLACEHOLDER_PATTERN)
            .flatten
            .uniq
            .reject { |token| ALLOWED_TEMPLATE_TOKENS.include?(token) }
      end
    end
  end
end
