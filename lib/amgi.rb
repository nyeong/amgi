# frozen_string_literal: true

module Amgi
  VERSION = '0.1.0'
end

require 'json'

require_relative 'amgi/application/build_deck'
require_relative 'amgi/application/lint_deck'
require_relative 'amgi/application/load_deck'
require_relative 'amgi/application/result'
require_relative 'amgi/development/anki_import_smoke'
require_relative 'amgi/development/apkg_metadata'
require_relative 'amgi/domain/build_artifact'
require_relative 'amgi/domain/build_config'
require_relative 'amgi/domain/deck_source'
require_relative 'amgi/domain/note_source'
require_relative 'amgi/domain/note_schema'
require_relative 'amgi/domain/template'
require_relative 'amgi/interfaces/cli/runner'
require_relative 'amgi/infrastructure/apkg_builder'
require_relative 'amgi/infrastructure/apkg_inspector'
require_relative 'amgi/infrastructure/furigana_formatter'
require_relative 'amgi/infrastructure/yaml_deck_loader'
