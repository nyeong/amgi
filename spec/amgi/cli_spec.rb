# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'amgi CLI' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:executable) { File.join(root, 'exe', 'amgi') }
  let(:deck_path) { File.join(root, 'spec', 'fixtures', 'decks', 'toeic') }
  let(:invalid_path) { File.join(root, 'spec', 'fixtures', 'decks', 'invalid_missing_required') }

  it 'lints a valid deck successfully' do
    stdout, stderr, status = Open3.capture3(
      'ruby',
      "-I#{File.join(root, 'lib')}",
      executable,
      'lint',
      deck_path
    )

    expect(status.exitstatus).to eq(0)
    expect(stdout).to include('Lint OK')
    expect(stderr).not_to include('Missing required field')
  end

  it 'fails lint for an invalid deck' do
    _stdout, stderr, status = Open3.capture3(
      'ruby',
      "-I#{File.join(root, 'lib')}",
      executable,
      'lint',
      invalid_path
    )

    expect(status.exitstatus).to eq(1)
    expect(stderr).to include('Missing required field `Meaning`')
  end

  it 'builds a valid deck into an apkg' do
    Dir.mktmpdir do |dir|
      stdout, _stderr, status = Open3.capture3(
        'ruby',
        "-I#{File.join(root, 'lib')}",
        executable,
        'build',
        deck_path,
        '--out',
        dir
      )

      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('.apkg')
    end
  end
end
