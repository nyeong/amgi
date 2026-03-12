# frozen_string_literal: true

module Amgi
  module Domain
    class NoteSource
      attr_reader :source_path, :notes, :enabled_cards

      def initialize(source_path:, notes:, enabled_cards: [])
        @source_path = source_path
        @notes = notes
        @enabled_cards = enabled_cards
      end
    end
  end
end
