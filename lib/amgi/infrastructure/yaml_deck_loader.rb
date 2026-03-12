# frozen_string_literal: true

require 'yaml'

module Amgi
  module Infrastructure
    class YamlDeckLoader
      CONFIG_FILE = 'amgi.yaml'

      def call(deck_path)
        Application::Result.success(
          Domain::DeckSource.new(
            deck_path: deck_path,
            config: load_build_config(deck_path),
            note_sources: load_note_sources(deck_path)
          )
        )
      rescue Psych::SyntaxError => e
        Application::Result.failure("YAML syntax error: #{e.message}")
      rescue KeyError => e
        Application::Result.failure(e.message)
      end

      private

      def load_build_config(deck_path)
        build_path = File.join(deck_path, CONFIG_FILE)
        raise KeyError, "Missing #{CONFIG_FILE} in #{deck_path}" unless File.exist?(build_path)

        build_config_from(YAML.load_file(build_path) || {})
      end

      def build_config_from(data)
        note_schema = data.fetch('note_schema')
        cards = Array(data.fetch('cards')).map do |card|
          Domain::Template.new(
            name: card.fetch('name'),
            front: card.fetch('front'),
            back: card.fetch('back'),
            default: card.fetch('default', false)
          )
        end

        Domain::BuildConfig.new(
          schema: data.fetch('schema'),
          name: data.fetch('name'),
          note_schema: Domain::NoteSchema.new(
            required_fields: Array(note_schema.fetch('required_fields')),
            optional_fields: Array(note_schema.fetch('optional_fields'))
          ),
          global_tags: Array(data['global_tags']),
          cards: cards,
          css: data['css']
        )
      end

      def load_note_sources(deck_path)
        Dir.glob(File.join(deck_path, '*.yaml'), sort: true).filter_map do |path|
          next if File.basename(path) == CONFIG_FILE

          data = YAML.load_file(path) || {}
          Domain::NoteSource.new(source_path: path, notes: Array(data['notes']))
        end
      end
    end
  end
end
