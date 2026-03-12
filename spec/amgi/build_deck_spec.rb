# frozen_string_literal: true

require 'json'
require 'sqlite3'
require 'tmpdir'
require 'zip'

RSpec.describe Amgi::Application::BuildDeck do
  let(:deck_path) { File.expand_path('../fixtures/decks/toeic', __dir__) }

  it 'builds an apkg with collection and media entries' do
    Dir.mktmpdir do |dir|
      output_path = File.join(dir, 'toeic.apkg')
      result = described_class.call(deck_path, output_path: output_path)

      expect(result).to be_success
      expect(File).to exist(result.value.output_path)
      expect(result.value.output_path).to eq(output_path)

      entries = Zip::File.open(result.value.output_path, &:entries).map(&:name)
      expect(entries).to include('collection.anki2', 'media')

      collection_path = File.join(dir, 'collection.anki2')
      Zip::File.open(result.value.output_path) do |zip_file|
        zip_file.extract('collection.anki2', collection_path)
      end

      db = SQLite3::Database.new(collection_path)
      note_count = db.get_first_value('SELECT COUNT(*) FROM notes')
      card_count = db.get_first_value('SELECT COUNT(*) FROM cards')
      tables = db.execute("SELECT name FROM sqlite_master WHERE type = 'table'").flatten
      models_json = db.get_first_value('SELECT models FROM col')
      decks_json = db.get_first_value('SELECT decks FROM col')
      dconf_json = db.get_first_value('SELECT dconf FROM col')
      media_json = Zip::File.open(result.value.output_path) { |zip_file| zip_file.read('media') }
      model = JSON.parse(models_json).values.first
      deck = JSON.parse(decks_json).values.first
      dconf = JSON.parse(dconf_json).values.first

      aggregate_failures do
        expect(note_count).to eq(2)
        expect(card_count).to eq(3)
        expect(tables).to include('col', 'notes', 'cards', 'revlog', 'graves')
        expect(JSON.parse(media_json)).to eq({})
        expect(model.fetch('css')).to be_a(String)
        expect(model.fetch('latexPre')).to be_a(String)
        expect(model.fetch('latexPost')).to be_a(String)
        expect(model.fetch('latexsvg')).to eq(false)
        expect(model.fetch('req')).to be_an(Array)
        expect(model.fetch('tmpls').size).to eq(2)
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

  it 'uses deck css when provided by the build config' do
    Dir.mktmpdir do |dir|
      deck_path = File.expand_path('../fixtures/decks/jlpt_css', __dir__)
      result = described_class.call(deck_path, output_path: File.join(dir, 'jlpt_css.apkg'))

      expect(result).to be_success

      collection_path = File.join(dir, 'collection.anki2')
      Zip::File.open(result.value.output_path) do |zip_file|
        zip_file.extract('collection.anki2', collection_path)
      end

      db = SQLite3::Database.new(collection_path)
      model = JSON.parse(db.get_first_value('SELECT models FROM col')).values.first

      expect(model.fetch('css')).to include('.memo')
    end
  end

  it 'derives ruby fields from target and reading when the schema asks for them' do
    Dir.mktmpdir do |dir|
      deck_path = File.expand_path('../fixtures/decks/jlpt_ruby', __dir__)
      result = described_class.call(deck_path, output_path: File.join(dir, 'jlpt_ruby.apkg'))

      expect(result).to be_success

      collection_path = File.join(dir, 'collection.anki2')
      Zip::File.open(result.value.output_path) do |zip_file|
        zip_file.extract('collection.anki2', collection_path)
      end

      db = SQLite3::Database.new(collection_path)
      fields = db.get_first_value('SELECT flds FROM notes').split("\x1F")

      aggregate_failures do
        expect(fields[4]).to eq('<ruby>与<rt>あた</rt></ruby>える')
        expect(fields[5]).to eq('大きな影響を<ruby>与<rt>あた</rt></ruby>える')
      end
    ensure
      db&.close
    end
  end

  it 'uses amgi.yaml output when no explicit output path is given' do
    deck_path = File.expand_path('../fixtures/decks/toeic_with_output', __dir__)
    result = described_class.call(deck_path, cwd: Dir.tmpdir)

    aggregate_failures do
      expect(result).to be_success
      expect(result.value.output_path).to eq(
        File.join(deck_path, 'build', 'toeic-from-config.apkg')
      )
      expect(File).to exist(result.value.output_path)
    end
  end

  it 'writes to the current working directory when no output is configured' do
    Dir.mktmpdir do |dir|
      result = described_class.call(deck_path, cwd: dir)

      aggregate_failures do
        expect(result).to be_success
        expect(result.value.output_path).to eq(File.join(dir, 'TOEIC_Vocabulary.apkg'))
        expect(File).to exist(result.value.output_path)
      end
    end
  end

  it 'keeps note and card identities stable when non-target fields change' do
    original_deck_path = File.expand_path('../fixtures/decks/stable_identity_original', __dir__)
    updated_deck_path = File.expand_path('../fixtures/decks/stable_identity_updated', __dir__)

    Dir.mktmpdir do |dir|
      original = described_class.call(
        original_deck_path,
        output_path: File.join(dir, 'original.apkg')
      )
      updated = described_class.call(updated_deck_path, output_path: File.join(dir, 'updated.apkg'))

      original_collection = extract_collection(original.value.output_path, dir, 'original.anki2')
      updated_collection = extract_collection(updated.value.output_path, dir, 'updated.anki2')

      original_db = SQLite3::Database.new(original_collection)
      updated_db = SQLite3::Database.new(updated_collection)

      original_note = original_db.get_first_row('SELECT id, guid, flds FROM notes')
      updated_note = updated_db.get_first_row('SELECT id, guid, flds FROM notes')
      original_card_id = original_db.get_first_value('SELECT id FROM cards')
      updated_card_id = updated_db.get_first_value('SELECT id FROM cards')

      aggregate_failures do
        expect(original).to be_success
        expect(updated).to be_success
        expect(original_note[0]).to eq(updated_note[0])
        expect(original_note[1]).to eq(updated_note[1])
        expect(original_card_id).to eq(updated_card_id)
        expect(original_note[2]).not_to eq(updated_note[2])
      end
    ensure
      original_db&.close
      updated_db&.close
    end
  end

  it 'builds only default cards when a dataset file does not opt into extra cards' do
    deck_path = File.expand_path('../fixtures/decks/default_only_cards', __dir__)

    Dir.mktmpdir do |dir|
      result = described_class.call(deck_path, output_path: File.join(dir, 'default_only.apkg'))

      expect(result).to be_success
      expect(result.value.card_count).to eq(2)
    end
  end

  def extract_collection(apkg_path, dir, filename)
    collection_path = File.join(dir, filename)
    Zip::File.open(apkg_path) do |zip_file|
      zip_file.extract('collection.anki2', collection_path)
    end
    collection_path
  end
end
