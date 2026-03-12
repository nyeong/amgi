# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Amgi::Infrastructure::ApkgInspector do
  let(:deck_path) { File.expand_path('../../fixtures/decks/toeic', __dir__) }

  it 'reads deck names and counts from a built apkg' do
    Dir.mktmpdir do |dir|
      build_result = Amgi::Application::BuildDeck.call(
        deck_path,
        output_path: File.join(dir, 'toeic.apkg')
      )
      metadata = described_class.new.call(build_result.value.output_path)

      aggregate_failures do
        expect(build_result).to be_success
        expect(metadata.deck_names).to include('TOEIC_Vocabulary')
        expect(metadata.note_count).to eq(2)
        expect(metadata.card_count).to eq(3)
      end
    end
  end
end
