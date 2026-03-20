# frozen_string_literal: true

module Amgi
  module Domain
    class NoteSource
      attr_reader :source_path, :notes, :enabled_cards, :deck_name

      def initialize(source_path:, notes:, deck_name:, enabled_cards: [])
        @source_path = source_path
        @notes = notes
        @deck_name = deck_name
        @enabled_cards = enabled_cards
      end
    end
  end
end
