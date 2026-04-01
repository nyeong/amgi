# frozen_string_literal: true

RSpec.describe Amgi::Domain::BlankFieldDsl do
  describe '.parse' do
    it 'renders full and blank text from blank markers' do
      rendered = described_class.parse('All employees must [[comply]] with the rules.')

      aggregate_failures do
        expect(rendered).to be_valid
        expect(rendered.blank_count).to eq(1)
        expect(rendered.full_text).to eq('All employees must comply with the rules.')
        expect(rendered.blank_text).to eq('All employees must [...] with the rules.')
      end
    end

    it 'uses the optional hint on the blank side' do
      rendered = described_class.parse('He [[went|go]] home early.')

      aggregate_failures do
        expect(rendered).to be_valid
        expect(rendered.full_text).to eq('He went home early.')
        expect(rendered.blank_text).to eq('He [go] home early.')
      end
    end

    it 'reports malformed markers' do
      rendered = described_class.parse('All employees must [[comply with the rules.')

      aggregate_failures do
        expect(rendered).not_to be_valid
        expect(rendered.errors).to include('Unclosed blank marker.')
      end
    end
  end
end
