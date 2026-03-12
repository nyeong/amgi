# frozen_string_literal: true

module Amgi
  module Application
    class LoadDeck
      def self.call(deck_path)
        Infrastructure::YamlDeckLoader.new.call(deck_path)
      end
    end
  end
end
