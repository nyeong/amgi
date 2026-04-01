# frozen_string_literal: true

module Amgi
  module Interfaces
    module CLI
      class Runner
        HELP_TEXT = <<~TEXT
          Usage:
            amgi help
            amgi lint <deck_dir>
            amgi build <deck_dir> [-o <output_path>]
        TEXT

        def call(argv)
          command = argv[0]
          deck_path = argv[1]

          case command
          when nil, 'help', '--help', '-h'
            print_help
          when 'lint'
            lint(deck_path)
          when 'build'
            build(deck_path, argv[2..])
          else
            warn "Unknown command: #{command}"
            warn
            warn HELP_TEXT
            1
          end
        end

        private

        def print_help
          puts HELP_TEXT
          0
        end

        def lint(deck_path)
          load_lint_dependencies
          load_result = Application::LoadDeck.call(deck_path)
          return print_errors(load_result.errors) unless load_result.success?

          lint_result = Application::LintDeck.call(load_result.value)
          return print_errors(lint_result.errors) unless lint_result.success?

          puts "Lint OK: #{deck_path} (#{lint_result.value.note_count} notes)"
          0
        end

        def build(deck_path, args)
          load_build_dependencies
          output_path = parse_output_path(args)
          result = Application::BuildDeck.call(deck_path, output_path: output_path, cwd: Dir.pwd)
          return print_errors(result.errors) unless result.success?

          puts "Build OK: #{result.value.output_path} (#{result.value.card_count} cards)"
          0
        end

        def parse_output_path(args)
          return nil unless args && !args.empty?

          option_index = args.find_index { |arg| %w[-o --out].include?(arg) }
          return nil unless option_index

          args[option_index + 1]
        end

        def print_errors(errors)
          Array(errors).each { |error| warn error }
          1
        end

        def load_lint_dependencies
          return if defined?(Application::LoadDeck) && defined?(Application::LintDeck)

          require_relative '../../application/result'
          require_relative '../../domain/blank_field_dsl'
          require_relative '../../domain/build_config'
          require_relative '../../domain/deck_source'
          require_relative '../../domain/note_source'
          require_relative '../../domain/note_schema'
          require_relative '../../domain/template'
          require_relative '../../infrastructure/yaml_deck_loader'
          require_relative '../../application/load_deck'
          require_relative '../../application/lint_deck'
        end

        def load_build_dependencies
          return if defined?(Application::BuildDeck)

          load_lint_dependencies
          require_relative '../../domain/build_artifact'
          require_relative '../../infrastructure/furigana_formatter'
          require_relative '../../infrastructure/apkg_builder'
          require_relative '../../application/build_deck'
        end
      end
    end
  end
end
