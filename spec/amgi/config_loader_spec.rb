# frozen_string_literal: true

RSpec.describe Amgi::Application::LoadDeck do
  subject(:result) { described_class.call(deck_path) }

  let(:deck_path) { File.expand_path('../fixtures/decks/toeic', __dir__) }

  it 'loads build config and note files in deterministic order' do
    expect(result).to be_success

    deck = result.value

    expect(deck.config.schema).to eq('amgi_v1')
    expect(deck.config.name).to eq('TOEIC_Vocabulary')
    expect(deck.config.required_fields).to eq(%w[Target Meaning])
    expect(deck.config.optional_fields).to eq(%w[Example BlankExample])
    expect(deck.config.all_fields).to eq(%w[Target Meaning Example BlankExample])
    expect(deck.note_sources.map(&:source_path)).to all(end_with('.yaml'))
    expect(deck.note_sources.flat_map(&:notes).size).to eq(2)
  end
end
