# frozen_string_literal: true

require 'json'
require 'sqlite3'
require 'tmpdir'
require 'zip'

RSpec.describe Amgi::Application::BuildDeck do
  let(:deck_path) { File.expand_path('../fixtures/decks/toeic', __dir__) }

  it 'builds an apkg with collection and media entries' do
    Dir.mktmpdir do |dir|
      result = described_class.call(deck_path, out_dir: dir)

      expect(result).to be_success
      expect(File).to exist(result.value.output_path)

      entries = Zip::File.open(result.value.output_path, &:entries).map(&:name)
      expect(entries).to include('collection.anki2', 'media')

      collection_path = File.join(dir, 'collection.anki2')
      Zip::File.open(result.value.output_path) do |zip_file|
        zip_file.extract('collection.anki2', collection_path)
      end

      db = SQLite3::Database.new(collection_path)
      note_count = db.get_first_value('SELECT COUNT(*) FROM notes')
      card_count = db.get_first_value('SELECT COUNT(*) FROM cards')
      models_json = db.get_first_value('SELECT models FROM col')
      decks_json = db.get_first_value('SELECT decks FROM col')
      dconf_json = db.get_first_value('SELECT dconf FROM col')
      media_json = Zip::File.open(result.value.output_path) { |zip_file| zip_file.read('media') }
      model = JSON.parse(models_json).values.first
      deck = JSON.parse(decks_json).values.first
      dconf = JSON.parse(dconf_json).values.first

      aggregate_failures do
        expect(note_count).to eq(2)
        expect(card_count).to eq(2)
        expect(JSON.parse(media_json)).to eq({})
        expect(model.fetch('css')).to be_a(String)
        expect(model.fetch('latexPre')).to be_a(String)
        expect(model.fetch('latexPost')).to be_a(String)
        expect(model.fetch('latexsvg')).to eq(false)
        expect(model.fetch('req')).to be_an(Array)
        expect(model.fetch('flds').first).to include(
          'sticky' => false,
          'rtl' => false,
          'font' => 'Arial',
          'size' => 20,
          'media' => []
        )
        expect(model.fetch('tmpls').first).to include(
          'bqfmt' => '',
          'bafmt' => '',
          'did' => nil,
          'bfont' => 'Arial',
          'bsize' => 20
        )
        expect(deck).to include(
          'dyn' => 0,
          'collapsed' => false,
          'browserCollapsed' => false,
          'conf' => 1
        )
        expect(dconf.fetch('name')).to eq('Default')
      end
    end
  end
end
