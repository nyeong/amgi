# frozen_string_literal: true

require 'open3'

RSpec.describe 'bin/amgi' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:executable) { File.join(root, 'bin', 'amgi') }
  let(:deck_path) { File.join(root, 'spec', 'fixtures', 'decks', 'toeic') }

  it 'runs the CLI through the shell wrapper' do
    stdout, _stderr, status = Open3.capture3(executable, 'lint', deck_path, chdir: root)

    expect(status.exitstatus).to eq(0)
    expect(stdout).to include('Lint OK')
  end
end
