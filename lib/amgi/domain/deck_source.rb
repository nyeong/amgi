# frozen_string_literal: true

module Amgi
  module Domain
    class DeckSource
      attr_reader :deck_path, :config, :note_sources

      def initialize(deck_path:, config:, note_sources:)
        @deck_path = deck_path
        @config = config
        @note_sources = note_sources
      end
    end
  end
end
