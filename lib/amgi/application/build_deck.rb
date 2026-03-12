# frozen_string_literal: true

module Amgi
  module Application
    class BuildDeck
      def self.call(deck_path, output_path: nil, cwd: Dir.pwd)
        new.call(deck_path, output_path: output_path, cwd: cwd)
      end

      def call(deck_path, output_path: nil, cwd: Dir.pwd)
        load_result = LoadDeck.call(deck_path)
        return load_result unless load_result.success?

        lint_result = LintDeck.call(load_result.value)
        return Result.failure(lint_result.errors) unless lint_result.success?

        Infrastructure::ApkgBuilder.new.call(
          lint_result.value,
          output_path: resolve_output_path(
            validated_deck: lint_result.value,
            explicit_output_path: output_path,
            cwd: cwd
          )
        )
      end

      private

      def resolve_output_path(validated_deck:, explicit_output_path:, cwd:)
        return expand_path(explicit_output_path, cwd) if explicit_output_path

        config_output = validated_deck.deck_source.config.output
        return expand_path(config_output, validated_deck.deck_source.deck_path) if config_output

        expand_path("#{sanitize(validated_deck.deck_source.config.name)}.apkg", cwd)
      end

      def expand_path(path, base_dir)
        return path if path.start_with?('/')

        File.expand_path(path, base_dir)
      end

      def sanitize(name)
        name.gsub(/[^A-Za-z0-9_-]+/, '_')
      end
    end
  end
end
