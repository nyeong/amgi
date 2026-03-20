# frozen_string_literal: true

RSpec.describe Amgi::Application::LoadDeck do
  subject(:result) { described_class.call(deck_path) }

  let(:deck_path) { File.expand_path('../fixtures/decks/toeic', __dir__) }

  it 'loads build config and note files in deterministic order' do
    expect(result).to be_success

    deck = result.value

    expect(deck.config.schema).to eq('amgi_v1')
    expect(deck.config.name).to eq('TOEIC_Vocabulary')
    expect(deck.config.css).to be_nil
    expect(deck.config.output).to be_nil
    expect(deck.config.note_schema.id).to eq('{{target}}')
    expect(deck.config.note_schema.required_fields).to eq(%w[target meaning])
    expect(deck.config.note_schema.optional_fields).to eq(%w[example blankExample])
    expect(deck.config.required_fields).to eq(%w[target meaning])
    expect(deck.config.optional_fields).to eq(%w[example blankExample])
    expect(deck.config.all_fields).to eq(%w[target meaning example blankExample])
    expect(deck.config.cards.map(&:name)).to eq(['Recall Meaning', 'Cloze Example'])
    expect(deck.note_sources.map(&:source_path)).to all(end_with('.yaml'))
    expect(deck.note_sources.flat_map(&:notes).size).to eq(2)
    expect(deck.note_sources.flat_map(&:notes).map { |note| note['target'] }).to eq(
      %w[comply invoice]
    )
    expect(deck.note_sources.first.enabled_cards).to eq(['Cloze Example'])
  end

  it 'ignores root-level dataset `_meta` fields' do
    expect(result).to be_success

    note_source = result.value.note_sources.find do |source|
      File.basename(source.source_path) == 'part5.yaml'
    end

    aggregate_failures do
      expect(note_source).not_to be_nil
      expect(note_source.notes.map { |note| note['target'] }).to eq(%w[comply invoice])
      expect(note_source.enabled_cards).to eq(['Cloze Example'])
    end
  end

  context 'when amgi.yaml defines an output path' do
    let(:deck_path) { File.expand_path('../fixtures/decks/toeic_with_output', __dir__) }

    it 'loads the output path' do
      expect(result).to be_success
      expect(result.value.config.output).to eq('build/toeic-from-config.apkg')
    end
  end

  context 'when loading a deck with the furigana toggle UI' do
    let(:deck_path) { File.expand_path('../fixtures/decks/furigana_toggle', __dir__) }

    it 'includes the furigana toggle UI in the card templates' do
      expect(result).to be_success

      css = result.value.config.css
      card_fronts = result.value.config.cards.map(&:front)

      aggregate_failures do
        expect(css).to include('.card.is-furigana-hidden ruby rt')
        expect(card_fronts).to all(include('data-furigana-toggle'))
        expect(card_fronts).to all(include('amgi.jlpt.showFurigana'))
      end
    end
  end

  context 'when a dataset file defines `_name`' do
    let(:deck_path) { File.expand_path('../fixtures/decks/source_named_subdecks', __dir__) }

    it 'branches that dataset into a subdeck name under the amgi deck name' do
      expect(result).to be_success

      root_source = result.value.note_sources.find do |source|
        File.basename(source.source_path) == 'a_root.yaml'
      end
      branch_source = result.value.note_sources.find do |source|
        File.basename(source.source_path) == 'b_branch.yaml'
      end

      aggregate_failures do
        expect(root_source.deck_name).to eq('SourceNamedDeck')
        expect(branch_source.deck_name).to eq('SourceNamedDeck::Verbs')
      end
    end
  end

  context 'when a dataset file uses mapping-style notes' do
    let(:deck_path) { File.expand_path('../fixtures/decks/invalid_notes_mapping', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include(
        "#{File.join(deck_path, 'cards.yaml')}: `notes` must be a list of note mappings"
      )
    end
  end

  context 'when a dataset file defines a blank `_name`' do
    let(:deck_path) { File.expand_path('../fixtures/decks/invalid_source_name_blank', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include(
        "#{File.join(deck_path, 'cards.yaml')}: `_name` must not be blank"
      )
    end
  end

  context 'when a dataset note is not a mapping' do
    let(:deck_path) { File.expand_path('../fixtures/decks/invalid_note_scalar', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include(
        "#{File.join(deck_path, 'cards.yaml')}:note#1 must be a mapping"
      )
    end
  end

  context 'when a dataset file defines `_cards` as a scalar' do
    let(:deck_path) { File.expand_path('../fixtures/decks/invalid_source_cards_scalar', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include('`_cards` must be a string array')
    end
  end

  context 'when amgi.yaml is missing' do
    let(:deck_path) { File.expand_path('../fixtures/decks/missing_amgi', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include("Missing amgi.yaml in #{deck_path}")
    end
  end
end
