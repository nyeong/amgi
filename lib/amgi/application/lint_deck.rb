# frozen_string_literal: true

module Amgi
  module Application
    class LintDeck
      PLACEHOLDER_PATTERN = /{{\s*([A-Za-z][A-Za-z0-9_]*)\s*}}/
      ALLOWED_TEMPLATE_TOKENS = %w[FrontSide].freeze
      FIELD_NAME_PATTERN = /\A[a-z][A-Za-z0-9]*\z/
      RESERVED_NOTE_KEYS = %w[tags cardIds].freeze

      ValidatedDeck = Struct.new(:deck_source, :note_count, keyword_init: true)

      def self.call(deck_source)
        new.call(deck_source)
      end

      def call(deck_source)
        errors = []
        config = deck_source.config

        validate_schema(config, errors)
        validate_cards(config, errors)
        validate_notes(config, deck_source.note_sources, errors)

        return Result.failure(errors) unless errors.empty?

        note_count = deck_source.note_sources.sum { |source| source.notes.size }
        Result.success(ValidatedDeck.new(deck_source: deck_source, note_count: note_count))
      end

      private

      def validate_schema(config, errors)
        errors << 'Unsupported schema. Expected `amgi_v1`.' unless config.schema == 'amgi_v1'
        errors << 'Deck name is required.' if blank_string?(config.name)
        errors << 'At least one required field is required.' if config.required_fields.empty?
        errors << 'At least one card is required.' if config.cards.empty?
        validate_css(config, errors)
        validate_field_name_convention(config.all_fields, errors)
        validate_cards_shape(config, errors)

        overlap = config.required_fields & config.optional_fields
        return if overlap.empty?

        errors << "Fields cannot be both required and optional: #{overlap.join(', ')}"
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
        validate_field_name_convention(config.card_ids, errors)

        duplicate_ids = duplicate_values(config.card_ids)
        errors << "Card ids must be unique: #{duplicate_ids.join(', ')}" unless duplicate_ids.empty?

        default_count = config.default_cards.size
        return if default_count == 1

        errors << 'Exactly one default card is required.'
      end

      def validate_notes(config, note_sources, errors)
        note_sources.each do |note_source|
          note_source.notes.each_with_index do |note, index|
            validate_note(config, note_source.source_path, note, index, errors)
          end
        end
      end

      def validate_note(config, source_path, note, index, errors)
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
        validate_card_ids(config, note, source_path, index, errors)
      end

      def validate_tags(note, source_path, index, errors)
        return if note['tags'].nil? || string_array?(note['tags'])

        errors << "#{source_path}:note##{index + 1} `tags` must be a string array"
      end

      def validate_card_ids(config, note, source_path, index, errors)
        return if note['cardIds'].nil?

        unless string_array?(note['cardIds'])
          errors << "#{source_path}:note##{index + 1} `cardIds` must be a string array"
          return
        end

        unknown_card_ids = note['cardIds'] - config.card_ids
        return if unknown_card_ids.empty?

        message = "#{source_path}:note##{index + 1} " \
                  "Unknown card id(s) `#{unknown_card_ids.join(', ')}`"
        errors << message
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

      def duplicate_values(values)
        values.group_by(&:itself).select { |_value, group| group.size > 1 }.keys
      end
    end
  end
end
