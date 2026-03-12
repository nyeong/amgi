# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'sqlite3'
require 'timeout'
require 'tmpdir'

module Amgi
  module Development
    class AnkiImportSmoke
      Result = Struct.new(
        :base_dir,
        :profile,
        :apkg_path,
        :log_path,
        :expected,
        :actual,
        keyword_init: true
      )

      DEFAULT_ANKI_APP = '/Applications/Anki.app'
      DEFAULT_PROFILE = 'AmgiSmoke'
      DEFAULT_TIMEOUT = 45
      DEFAULT_SETTLE_SECONDS = 10

      def initialize(inspector: Infrastructure::ApkgInspector.new)
        @inspector = inspector
      end

      def call(apkg_path, options = {})
        options = {
          anki_app: DEFAULT_ANKI_APP,
          timeout_seconds: DEFAULT_TIMEOUT,
          settle_seconds: DEFAULT_SETTLE_SECONDS,
          base_dir: nil,
          profile: DEFAULT_PROFILE,
          keep_temp: false
        }.merge(options)

        raise ArgumentError, "Missing apkg: #{apkg_path}" unless File.exist?(apkg_path)

        launcher_path = File.join(options[:anki_app], 'Contents', 'MacOS', 'launcher')
        validate_anki_environment!(launcher_path)
        expected = @inspector.call(apkg_path)
        with_base_dir(options[:base_dir], keep_temp: options[:keep_temp]) do |resolved_base_dir|
          run_import(
            {
              launcher_path: launcher_path,
              base_dir: resolved_base_dir,
              profile: options[:profile],
              apkg_path: apkg_path,
              expected: expected,
              timeout_seconds: options[:timeout_seconds],
              settle_seconds: options[:settle_seconds]
            }
          )
        end
      rescue StandardError
        quit_anki
        raise
      end

      private

      def validate_anki_environment!(launcher_path)
        if anki_running?
          raise ArgumentError, 'Anki already appears to be running. Quit it before smoke testing.'
        end

        return if File.executable?(launcher_path)

        raise ArgumentError, "Anki launcher not found: #{launcher_path}"
      end

      def with_base_dir(base_dir, keep_temp:)
        return yield(base_dir) if base_dir

        created_base_dir = Dir.mktmpdir('amgi-anki-import')
        yield(created_base_dir)
      ensure
        if !base_dir && !keep_temp && !$ERROR_INFO && !created_base_dir.nil?
          FileUtils.rm_rf(created_base_dir)
        end
      end

      def run_import(options)
        log_path = File.join(options[:base_dir], 'anki-smoke.log')
        pid = spawn_anki(
          options[:launcher_path],
          options[:base_dir],
          options[:profile],
          options[:apkg_path],
          log_path
        )
        wait_for_gui_ready(
          options[:base_dir],
          options[:profile],
          log_path,
          options[:timeout_seconds]
        )
        sleep options[:settle_seconds]

        quit_anki
        wait_for_exit(pid)
        actual = final_collection_state(options[:base_dir], options[:profile])
        verify_final_import!(options[:expected], actual, options[:base_dir])

        Result.new(
          base_dir: options[:base_dir],
          profile: options[:profile],
          apkg_path: options[:apkg_path],
          log_path: log_path,
          expected: options[:expected],
          actual: actual
        )
      end

      def spawn_anki(launcher_path, base_dir, profile, apkg_path, log_path)
        Process.spawn(
          launcher_path,
          '--safemode',
          '--base',
          base_dir,
          '--profile',
          profile,
          apkg_path,
          out: log_path,
          err: log_path
        )
      end

      def wait_for_gui_ready(base_dir, profile, log_path, timeout_seconds)
        Timeout.timeout(timeout_seconds) do
          loop do
            collection_ready = profile_collection_path(base_dir, profile)
            return if collection_ready || main_loop_started?(log_path)

            sleep 1
          end
        end
      rescue Timeout::Error
        raise "Timed out waiting for Anki to start after #{timeout_seconds}s in #{base_dir}"
      end

      def current_collection_state(collection_path)
        counts = current_collection_counts(collection_path)
        return nil unless counts

        ApkgMetadata.new(
          deck_names: current_collection_decks(collection_path),
          note_count: counts[:note_count],
          card_count: counts[:card_count]
        )
      end

      def current_collection_counts(collection_path)
        db = SQLite3::Database.new(collection_path, readonly: true)
        db.busy_timeout = 250

        {
          note_count: db.get_first_value('SELECT COUNT(*) FROM notes'),
          card_count: db.get_first_value('SELECT COUNT(*) FROM cards')
        }
      rescue SQLite3::BusyException, SQLite3::SQLException
        nil
      ensure
        db&.close
      end

      def current_collection_decks(collection_path)
        db = SQLite3::Database.new(collection_path, readonly: true)
        db.busy_timeout = 250

        JSON.parse(db.get_first_value('SELECT decks FROM col')).values.map do |deck|
          deck.fetch('name')
        end
      rescue JSON::ParserError, SQLite3::BusyException, SQLite3::SQLException
        []
      ensure
        db&.close
      end

      def final_collection_state(base_dir, profile)
        Timeout.timeout(10) do
          loop do
            collection_path = profile_collection_path(base_dir, profile)
            state = collection_path && current_collection_state(collection_path)
            return state if state

            sleep 0.5
          end
        end
      rescue Timeout::Error
        raise "Imported collection did not reach a readable final state in #{base_dir}"
      end

      def verify_final_import!(expected, actual, base_dir)
        enough_notes = actual.note_count >= expected.note_count
        enough_cards = actual.card_count >= expected.card_count
        return if enough_notes && enough_cards

        raise "Anki import smoke test did not import expected notes/cards in #{base_dir}"
      end

      def profile_collection_path(base_dir, profile)
        direct_path = File.join(base_dir, profile, 'collection.anki2')
        return direct_path if File.exist?(direct_path)

        Dir.glob(File.join(base_dir, '**', 'collection.anki2')).first
      end

      def quit_anki
        system(
          '/usr/bin/osascript',
          '-e',
          'tell application "Anki" to quit',
          out: File::NULL,
          err: File::NULL
        )
      end

      def wait_for_exit(pid)
        Timeout.timeout(15) do
          Process.wait(pid)
        end
      rescue Timeout::Error
        Process.kill('TERM', pid)
        sleep 1
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end

      def anki_running?
        system('/usr/bin/pgrep', '-x', 'Anki', out: File::NULL, err: File::NULL)
      end

      def main_loop_started?(log_path)
        return false unless File.exist?(log_path)

        File.read(log_path).include?('Starting main loop...')
      end
    end
  end
end
