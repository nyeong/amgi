# frozen_string_literal: true

module Amgi
  module Domain
    class Template
      attr_reader :id, :name, :front, :back

      def initialize(id:, name:, front:, back:, default: false)
        @id = id
        @name = name
        @front = front
        @back = back
        @default = default
      end

      def default?
        @default
      end
    end
  end
end
