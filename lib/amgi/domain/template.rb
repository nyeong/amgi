# frozen_string_literal: true

module Amgi
  module Domain
    class Template
      attr_reader :name, :front, :back

      def initialize(name:, front:, back:)
        @name = name
        @front = front
        @back = back
      end
    end
  end
end
