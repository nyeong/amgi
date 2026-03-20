# frozen_string_literal: true

require 'yaml'

module Amgi
  module Infrastructure
    class YamlDeckLoader
      CONFIG_FILE = 'amgi.yaml'
      LEGACY_ROOT_KEYS = {
        'cards' => '_cards',
        'meta' => '_meta',
        'name' => '_name'
      }.freeze

      def call(deck_path)
        config = load_build_config(deck_path)

        Application::Result.success(
          Domain::DeckSource.new(
            deck_path: deck_path,
            config: config,
            note_sources: load_note_sources(deck_path, base_deck_name: config.name)
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
            id: note_schema.fetch('id'),
            required_fields: Array(note_schema.fetch('required_fields')),
            optional_fields: Array(note_schema.fetch('optional_fields'))
          ),
          global_tags: Array(data['global_tags']),
          cards: cards,
          css: data['css'],
          output: data['output']
        )
      end

      def load_note_sources(deck_path, base_deck_name:)
        Dir.glob(File.join(deck_path, '*.yaml'), sort: true).filter_map do |path|
          next if File.basename(path) == CONFIG_FILE

          data = YAML.load_file(path) || {}
          Domain::NoteSource.new(
            source_path: path,
            notes: normalize_notes(path, data['notes']),
            enabled_cards: normalize_enabled_cards(
              path,
              dataset_root_value(data, path, key: 'cards')
            ),
            deck_name: normalize_deck_name(
              path,
              base_deck_name,
              dataset_root_value(data, path, key: 'name')
            )
          )
        end
      end

      def normalize_enabled_cards(source_path, enabled_cards)
        return [] if enabled_cards.nil?

        unless enabled_cards.is_a?(Array)
          raise KeyError, "#{source_path}: `cards` must be a string array"
        end

        enabled_cards.map(&:to_s)
      end

      def normalize_deck_name(source_path, base_deck_name, source_name)
        return base_deck_name if source_name.nil?
        raise KeyError, "#{source_path}: `name` must be a string" unless source_name.is_a?(String)

        source_name = source_name.strip
        raise KeyError, "#{source_path}: `name` must not be blank" if source_name.empty?

        "#{base_deck_name}::#{source_name}"
      end

      def dataset_root_value(data, source_path, key:)
        legacy_key = LEGACY_ROOT_KEYS.fetch(key)
        return data[key] if data.key?(key) && !data.key?(legacy_key)
        return data[legacy_key] if data.key?(legacy_key) && !data.key?(key)
        return nil unless data.key?(key) && data.key?(legacy_key)

        raise KeyError, "#{source_path}: use either `#{key}` or `#{legacy_key}`, not both"
      end

      def normalize_notes(source_path, notes)
        return [] if notes.nil?

        unless notes.is_a?(Array)
          raise KeyError, "#{source_path}: `notes` must be a list of note mappings"
        end

        notes.map.with_index do |note, index|
          normalize_note(source_path, note, index)
        end
      end

      def normalize_note(source_path, note, index)
        raise KeyError, "#{source_path}:note##{index + 1} must be a mapping" unless note.is_a?(Hash)

        note.transform_keys(&:to_s)
      end
    end
  end
end
