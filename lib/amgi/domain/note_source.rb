# frozen_string_literal: true

module Amgi
  module Domain
    class NoteSource
      attr_reader :source_path, :notes

      def initialize(source_path:, notes:)
        @source_path = source_path
        @notes = notes
      end
    end
  end
end
