# frozen_string_literal: true

module Amgi
  module Application
    class BuildDeck
      def self.call(deck_path, out_dir: nil)
        new.call(deck_path, out_dir: out_dir)
      end

      def call(deck_path, out_dir: nil)
        load_result = LoadDeck.call(deck_path)
        return load_result unless load_result.success?

        lint_result = LintDeck.call(load_result.value)
        return Result.failure(lint_result.errors) unless lint_result.success?

        Infrastructure::ApkgBuilder.new.call(
          lint_result.value,
          out_dir: out_dir || File.join(deck_path, 'dist')
        )
      end
    end
  end
end
