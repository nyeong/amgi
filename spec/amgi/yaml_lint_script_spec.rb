# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'yaml lint script' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:script) { File.join(root, 'bin', 'lint-yaml') }

  it 'passes when all yaml files are valid' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'valid.yaml'), <<~YAML)
        key:
          - value
      YAML

      stdout, stderr, status = Open3.capture3('ruby', script, chdir: dir)

      aggregate_failures do
        expect(status.exitstatus).to eq(0)
        expect(stdout).to include('YAML OK: 1 file(s)')
        expect(stderr).not_to include('valid.yaml:')
      end
    end
  end

  it 'fails when a yaml file has invalid syntax' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'broken.yaml'), <<~YAML)
        key:
          - value
          bad: [
      YAML

      _stdout, stderr, status = Open3.capture3('ruby', script, chdir: dir)

      aggregate_failures do
        expect(status.exitstatus).to eq(1)
        expect(stderr).to include('broken.yaml:')
      end
    end
  end
end
