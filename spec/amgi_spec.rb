# frozen_string_literal: true

RSpec.describe Amgi do
  it 'exposes a version constant for smoke testing' do
    expect(Amgi::VERSION).to be_a(String)
  end
end
