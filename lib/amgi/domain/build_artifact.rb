# frozen_string_literal: true

module Amgi
  module Domain
    class BuildArtifact
      attr_reader :output_path, :note_count, :card_count

      def initialize(output_path:, note_count:, card_count:)
        @output_path = output_path
        @note_count = note_count
        @card_count = card_count
      end
    end
  end
end
