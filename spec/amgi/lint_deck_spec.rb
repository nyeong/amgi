# frozen_string_literal: true

RSpec.describe Amgi::Application::LintDeck do
  def fixture_path(name)
    File.expand_path("../fixtures/decks/#{name}", __dir__)
  end

  it 'accepts a valid deck' do
    loaded = Amgi::Application::LoadDeck.call(fixture_path('toeic'))
    result = described_class.call(loaded.value)

    aggregate_failures do
      expect(loaded).to be_success
      expect(result).to be_success
      expect(result.value.note_count).to eq(2)
    end
  end

  it 'rejects a note missing a required field' do
    loaded = Amgi::Application::LoadDeck.call(fixture_path('invalid_missing_required'))
    result = described_class.call(loaded.value)

    expect(result).not_to be_success
    expect(result.errors.join("\n")).to include('Missing required field `meaning`')
  end

  it 'rejects unknown template placeholders' do
    loaded = Amgi::Application::LoadDeck.call(fixture_path('invalid_placeholder'))
    result = described_class.call(loaded.value)

    expect(result).not_to be_success
    expect(result.errors.join("\n")).to include('Unknown template placeholder `unknownField`')
  end

  it 'rejects field declarations that do not start with lowercase' do
    loaded = Amgi::Application::LoadDeck.call(fixture_path('invalid_field_name'))
    result = described_class.call(loaded.value)

    expect(result).not_to be_success
    expect(result.errors.join("\n")).to include(
      'Field names must start with a lowercase letter: Target'
    )
  end
end
