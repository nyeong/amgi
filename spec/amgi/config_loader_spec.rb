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
    expect(deck.config.note_schema.required_fields).to eq(%w[target meaning])
    expect(deck.config.note_schema.optional_fields).to eq(%w[example blankExample])
    expect(deck.config.required_fields).to eq(%w[target meaning])
    expect(deck.config.optional_fields).to eq(%w[example blankExample])
    expect(deck.config.all_fields).to eq(%w[target meaning example blankExample])
    expect(deck.config.cards.map(&:name)).to eq(['Recall Meaning', 'Cloze Example'])
    expect(deck.note_sources.map(&:source_path)).to all(end_with('.yaml'))
    expect(deck.note_sources.flat_map(&:notes).size).to eq(2)
  end

  context 'when amgi.yaml is missing' do
    let(:deck_path) { File.expand_path('../fixtures/decks/missing_amgi', __dir__) }

    it 'returns a load error' do
      expect(result).not_to be_success
      expect(result.errors).to include("Missing amgi.yaml in #{deck_path}")
    end
  end
end
