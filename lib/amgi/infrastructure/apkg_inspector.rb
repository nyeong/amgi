# frozen_string_literal: true

require 'json'
require 'sqlite3'
require 'tmpdir'
require 'zip'

module Amgi
  module Infrastructure
    class ApkgInspector
      def call(apkg_path)
        Dir.mktmpdir('amgi-apkg-inspect') do |dir|
          collection_path = extract_collection(apkg_path, dir)
          db = SQLite3::Database.new(collection_path)

          deck_names = JSON.parse(db.get_first_value('SELECT decks FROM col')).values.map do |deck|
            deck.fetch('name')
          end

          Development::ApkgMetadata.new(
            deck_names: deck_names,
            note_count: db.get_first_value('SELECT COUNT(*) FROM notes'),
            card_count: db.get_first_value('SELECT COUNT(*) FROM cards')
          )
        ensure
          db&.close
        end
      end

      private

      def extract_collection(apkg_path, dir)
        collection_path = File.join(dir, 'collection.anki2')

        Zip::File.open(apkg_path) do |zip_file|
          zip_file.extract('collection.anki2', collection_path)
        end

        collection_path
      end
    end
  end
end
