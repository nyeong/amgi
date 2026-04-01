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
      note_fields = db.execute('SELECT flds FROM notes ORDER BY id').map do |row|
        row.first.split("\x1F", -1)
      end
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
        expect(note_fields.first).to eq(
          [
            'comply',
            '준수하다, 따르다',
            'All employees must comply with the rules.',
            'All employees must [...] with the rules.'
          ]
        )
        expect(note_fields.last).to eq(
          [
            'invoice',
            '송장, 청구서',
            '',
            ''
          ]
        )
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

  it 'changes note and card identities when note_schema.id changes output' do
    original_deck_path = File.expand_path(
      '../fixtures/decks/configurable_identity_original',
      __dir__
    )
    updated_deck_path = File.expand_path(
      '../fixtures/decks/configurable_identity_updated',
      __dir__
    )

    Dir.mktmpdir do |dir|
      original = described_class.call(
        original_deck_path,
        output_path: File.join(dir, 'original.apkg')
      )
      updated = described_class.call(updated_deck_path, output_path: File.join(dir, 'updated.apkg'))

      original_collection = extract_collection(
        original.value.output_path,
        dir,
        'original-custom.anki2'
      )
      updated_collection = extract_collection(
        updated.value.output_path,
        dir,
        'updated-custom.anki2'
      )

      original_db = SQLite3::Database.new(original_collection)
      updated_db = SQLite3::Database.new(updated_collection)

      original_note = original_db.get_first_row('SELECT id, guid FROM notes')
      updated_note = updated_db.get_first_row('SELECT id, guid FROM notes')
      original_card_id = original_db.get_first_value('SELECT id FROM cards')
      updated_card_id = updated_db.get_first_value('SELECT id FROM cards')

      aggregate_failures do
        expect(original).to be_success
        expect(updated).to be_success
        expect(original_note[0]).not_to eq(updated_note[0])
        expect(original_note[1]).not_to eq(updated_note[1])
        expect(original_card_id).not_to eq(updated_card_id)
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

  it 'branches cards into dataset subdecks when a source defines `name`' do
    deck_path = File.expand_path('../fixtures/decks/source_named_subdecks', __dir__)

    Dir.mktmpdir do |dir|
      result = described_class.call(deck_path, output_path: File.join(dir, 'source_named.apkg'))

      expect(result).to be_success

      collection_path = extract_collection(result.value.output_path, dir, 'source_named.anki2')
      db = SQLite3::Database.new(collection_path)
      decks = JSON.parse(db.get_first_value('SELECT decks FROM col'))
      id_to_name = decks.values.to_h { |deck| [deck.fetch('id'), deck.fetch('name')] }
      card_deck_names = db.execute('SELECT did FROM cards ORDER BY due').flatten.map do |deck_id|
        id_to_name.fetch(deck_id)
      end

      aggregate_failures do
        expect(decks.values.map { |deck| deck.fetch('name') }).to include(
          'SourceNamedDeck',
          'SourceNamedDeck::Verbs'
        )
        expect(card_deck_names).to eq(['SourceNamedDeck', 'SourceNamedDeck::Verbs'])
      end
    ensure
      db&.close
    end
  end

  it 'keeps named-dataset cards attached to models that default to the same deck' do
    deck_path = File.expand_path('../fixtures/decks/source_named_subdecks', __dir__)

    Dir.mktmpdir do |dir|
      result = described_class.call(deck_path, output_path: File.join(dir, 'source_named.apkg'))

      expect(result).to be_success

      collection_path = extract_collection(result.value.output_path, dir, 'source_named.anki2')
      db = SQLite3::Database.new(collection_path)
      models = JSON.parse(db.get_first_value('SELECT models FROM col')).transform_values do |model|
        model.fetch('did')
      end
      note_rows = db.execute('SELECT id, flds, mid FROM notes ORDER BY id').to_h do |id, flds, mid|
        [id, { target: flds.split("\x1F").first, model_deck_id: models.fetch(mid.to_s) }]
      end
      note_deck_ids = db.execute('SELECT nid, did FROM cards ORDER BY due').to_h do |nid, did|
        target = note_rows.fetch(nid).fetch(:target)
        [target, { card_deck_id: did, model_deck_id: note_rows.fetch(nid).fetch(:model_deck_id) }]
      end

      aggregate_failures do
        expect(note_deck_ids.fetch('root')).to include(
          card_deck_id: note_deck_ids.fetch('root').fetch(:model_deck_id)
        )
        expect(note_deck_ids.fetch('branch')).to include(
          card_deck_id: note_deck_ids.fetch('branch').fetch(:model_deck_id)
        )
      end
    ensure
      db&.close
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
