# frozen_string_literal: true

module Amgi
  module Application
    class LintDeck
      PLACEHOLDER_PATTERN = /{{\s*([A-Za-z][A-Za-z0-9_]*)\s*}}/
      ALLOWED_TEMPLATE_TOKENS = %w[FrontSide].freeze
      FIELD_NAME_PATTERN = /\A[a-z][A-Za-z0-9]*\z/
      RESERVED_NOTE_KEYS = %w[_tags].freeze

      ValidatedDeck = Struct.new(:deck_source, :note_count, keyword_init: true)

      def self.call(deck_source)
        new.call(deck_source)
      end

      def call(deck_source)
        errors = []
        config = deck_source.config

        validate_schema(config, errors)
        validate_cards(config, errors)
        validate_note_sources(config, deck_source.note_sources, errors)

        return Result.failure(errors) unless errors.empty?

        note_count = deck_source.note_sources.sum { |source| source.notes.size }
        Result.success(ValidatedDeck.new(deck_source: deck_source, note_count: note_count))
      end

      private

      def validate_schema(config, errors)
        errors << 'Unsupported schema. Expected `amgi_v1`.' unless config.schema == 'amgi_v1'
        errors << 'Deck name is required.' if blank_string?(config.name)
        validate_note_id_schema(config, errors)
        errors << 'At least one required field is required.' if config.required_fields.empty?
        errors << 'At least one card is required.' if config.cards.empty?
        validate_css(config, errors)
        validate_field_name_convention(config.all_fields, errors)
        validate_cards_shape(config, errors)

        overlap = config.required_fields & config.optional_fields
        return if overlap.empty?

        errors << "Fields cannot be both required and optional: #{overlap.join(', ')}"
      end

      def validate_note_id_schema(config, errors)
        note_id = config.note_schema.id
        errors << '`note_schema.id` is required.' if note_id.nil?
        errors << '`note_schema.id` must be a string.' unless note_id.nil? || note_id.is_a?(String)

        unknown_tokens = config.note_schema.id_fields - config.all_fields
        return if unknown_tokens.empty?

        errors << "Unknown note id placeholder(s): #{unknown_tokens.join(', ')}"
      end

      def validate_css(config, errors)
        return if config.css.nil? || config.css.is_a?(String)

        errors << '`css` must be a string when provided.'
      end

      def validate_field_name_convention(fields, errors)
        invalid_fields = fields.grep_v(FIELD_NAME_PATTERN)
        return if invalid_fields.empty?

        errors << "Field names must start with a lowercase letter: #{invalid_fields.join(', ')}"
      end

      def validate_cards(config, errors)
        allowed_fields = config.all_fields + ALLOWED_TEMPLATE_TOKENS

        config.cards.each do |card|
          [card.front, card.back].each do |body|
            body.to_s.scan(PLACEHOLDER_PATTERN).flatten.each do |token|
              next if allowed_fields.include?(token)

              errors << "Unknown card placeholder `#{token}` in card `#{card.name}`"
            end
          end
        end
      end

      def validate_cards_shape(config, errors)
        default_count = config.default_cards.size
        return if default_count == 1

        errors << 'Exactly one default card is required.'
      end

      def validate_note_sources(config, note_sources, errors)
        seen_note_ids = {}

        note_sources.each do |note_source|
          validate_note_source(config, note_source, errors)
          note_source.notes.each_with_index do |note, index|
            validate_note(config, note_source.source_path, note, index, seen_note_ids, errors)
          end
        end
      end

      def validate_note_source(config, note_source, errors)
        unless string_array?(note_source.enabled_cards)
          errors << "#{note_source.source_path}: `_cards` must be a string array"
          return
        end

        unknown_cards = note_source.enabled_cards - config.cards.map(&:name)
        return if unknown_cards.empty?

        errors << (
          "#{note_source.source_path}: Unknown dataset `_cards`: #{unknown_cards.join(', ')}"
        )
      end

      def validate_note(config, source_path, note, index, seen_note_ids, errors)
        unless note.is_a?(Hash)
          errors << "#{source_path}:note##{index + 1} must be a mapping"
          return
        end

        config.required_fields.each do |field|
          next if present_value?(note[field])

          errors << "#{source_path}:note##{index + 1} Missing required field `#{field}`"
        end

        allowed_keys = config.all_fields + RESERVED_NOTE_KEYS
        unknown_keys = note.keys - allowed_keys
        unknown_keys.each do |key|
          errors << "#{source_path}:note##{index + 1} Unknown field `#{key}`"
        end

        validate_tags(note, source_path, index, errors)
        validate_note_identity(config, note, source_path, index, seen_note_ids, errors)
      end

      def validate_tags(note, source_path, index, errors)
        return if note['_tags'].nil? || string_array?(note['_tags'])

        errors << "#{source_path}:note##{index + 1} `_tags` must be a string array"
      end

      def validate_note_identity(config, note, source_path, index, seen_note_ids, errors)
        note_id = config.note_schema.render_id(note)

        if blank_string?(note_id)
          errors << "#{source_path}:note##{index + 1} Rendered note id must not be blank"
          return
        end

        return unless seen_note_ids.key?(note_id)

        errors << (
          "#{source_path}:note##{index + 1} Duplicate note id `#{note_id}` " \
          "(already used by #{seen_note_ids.fetch(note_id)})"
        )
      ensure
        seen_note_ids[note_id] ||= "#{source_path}:note##{index + 1}" if note_id
      end

      def blank_string?(value)
        value.to_s.strip.empty?
      end

      def present_value?(value)
        !value.nil? && !blank_string?(value)
      end

      def string_array?(value)
        value.is_a?(Array) && value.all? { |item| item.is_a?(String) }
      end
    end
  end
end
