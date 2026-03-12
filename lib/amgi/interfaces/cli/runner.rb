# frozen_string_literal: true

module Amgi
  module Interfaces
    module CLI
      class Runner
        def call(argv)
          command = argv[0]
          deck_path = argv[1]

          case command
          when 'lint'
            lint(deck_path)
          when 'build'
            build(deck_path, argv[2..])
          else
            warn "Unknown command: #{command}"
            1
          end
        end

        private

        def lint(deck_path)
          load_result = Application::LoadDeck.call(deck_path)
          return print_errors(load_result.errors) unless load_result.success?

          lint_result = Application::LintDeck.call(load_result.value)
          return print_errors(lint_result.errors) unless lint_result.success?

          puts "Lint OK: #{deck_path} (#{lint_result.value.note_count} notes)"
          0
        end

        def build(deck_path, args)
          out_dir = parse_out_dir(args)
          result = Application::BuildDeck.call(deck_path, out_dir: out_dir)
          return print_errors(result.errors) unless result.success?

          puts "Build OK: #{result.value.output_path} (#{result.value.card_count} cards)"
          0
        end

        def parse_out_dir(args)
          return nil unless args && !args.empty?

          out_index = args.index('--out')
          return nil unless out_index

          args[out_index + 1]
        end

        def print_errors(errors)
          Array(errors).each { |error| warn error }
          1
        end
      end
    end
  end
end
