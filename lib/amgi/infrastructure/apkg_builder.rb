# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require 'json'
require 'sqlite3'
require 'tmpdir'
require 'zip'

module Amgi
  module Infrastructure
    class ApkgBuilder
      ANKI_COLLECTION_SCHEMA = [
        <<~SQL,
          CREATE TABLE col (
            id integer primary key,
            crt integer not null,
            mod integer not null,
            scm integer not null,
            ver integer not null,
            dty integer not null,
            usn integer not null,
            ls integer not null,
            conf text not null,
            models text not null,
            decks text not null,
            dconf text not null,
            tags text not null
          )
        SQL
        <<~SQL,
          CREATE TABLE notes (
            id integer primary key,
            guid text not null,
            mid integer not null,
            mod integer not null,
            usn integer not null,
            tags text not null,
            flds text not null,
            sfld integer not null,
            csum integer not null,
            flags integer not null,
            data text not null
          )
        SQL
        <<~SQL,
          CREATE TABLE cards (
            id integer primary key,
            nid integer not null,
            did integer not null,
            ord integer not null,
            mod integer not null,
            usn integer not null,
            type integer not null,
            queue integer not null,
            due integer not null,
            ivl integer not null,
            factor integer not null,
            reps integer not null,
            lapses integer not null,
            left integer not null,
            odue integer not null,
            odid integer not null,
            flags integer not null,
            data text not null
          )
        SQL
        <<~SQL,
          CREATE TABLE revlog (
            id integer primary key,
            cid integer not null,
            usn integer not null,
            ease integer not null,
            ivl integer not null,
            lastIvl integer not null,
            factor integer not null,
            time integer not null,
            type integer not null
          )
        SQL
        <<~SQL
          CREATE TABLE graves (
            usn integer not null,
            oid integer not null,
            type integer not null
          )
        SQL
      ].freeze
      DEFAULT_MODEL_CSS = <<~CSS
        .card {
          font-family: arial;
          font-size: 20px;
          text-align: center;
          color: black;
          background-color: white;
        }
      CSS
      DEFAULT_LATEX_PRE = <<~LATEX
        \\documentclass[12pt]{article}
        \\special{papersize=3in,5in}
        \\usepackage[utf8]{inputenc}
        \\usepackage{amssymb,amsmath}
        \\pagestyle{empty}
        \\setlength{\\parindent}{0in}
        \\begin{document}
      LATEX
      DEFAULT_LATEX_POST = '\\end{document}'
      DERIVED_FIELD_BUILDERS = {
        'rubyTarget' => lambda { |note, formatter|
          formatter.ruby(text: note['target'], reading: note['reading'])
        },
        'rubyContext' => lambda { |note, formatter|
          formatter.annotate(
            text: note['context'],
            phrase: note['target'],
            phrase_reading: note['reading']
          )
        }
      }.freeze

      def call(validated_deck, output_path:)
        FileUtils.mkdir_p(File.dirname(output_path))
        deck_names = collection_deck_names(validated_deck.deck_source)
        model_ids = model_ids_by_deck(validated_deck.deck_source.note_sources.map(&:deck_name))
        note_rows, card_rows = build_rows(validated_deck)

        Dir.mktmpdir('amgi-build') do |tmp_dir|
          collection_path = File.join(tmp_dir, 'collection.anki2')
          build_collection(
            collection_path: collection_path,
            validated_deck: validated_deck,
            deck_names: deck_names,
            model_ids: model_ids,
            note_rows: note_rows,
            card_rows: card_rows
          )
          write_apkg(output_path: output_path, collection_path: collection_path)
        end

        Application::Result.success(
          Domain::BuildArtifact.new(
            output_path: output_path,
            note_count: note_rows.size,
            card_count: card_rows.size
          )
        )
      end

      private

      def build_rows(validated_deck)
        config = validated_deck.deck_source.config
        deck_seed = config.name
        build_context = {
          config: config,
          deck_seed: deck_seed,
          model_ids: model_ids_by_deck(validated_deck.deck_source.note_sources.map(&:deck_name)),
          timestamp: Time.now.to_i,
          note_rows: [],
          card_rows: []
        }
        due = 1

        validated_deck.deck_source.note_sources.each do |note_source|
          due = append_note_source_rows(
            note_source: note_source,
            due: due,
            build_context: build_context
          )
        end

        [build_context.fetch(:note_rows), build_context.fetch(:card_rows)]
      end

      def note_row(config:, note:, note_id:, model_id:, guid:, timestamp:)
        tags = merged_tags(config.global_tags, note['_tags'])
        joined_fields = config.all_fields.map { |field| field_value(note, field) }.join("\x1F")
        sort_field = note[config.required_fields.first].to_s

        [
          note_id,
          guid,
          model_id,
          timestamp,
          -1,
          format_tags(tags),
          joined_fields,
          sort_field,
          checksum(sort_field),
          0,
          ''
        ]
      end

      def card_row(card_id:, note_id:, deck_id:, ord:, due:, timestamp:)
        [
          card_id,
          note_id,
          deck_id,
          ord,
          timestamp,
          -1,
          0,
          0,
          due,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          ''
        ]
      end

      def build_collection(
        collection_path:,
        validated_deck:,
        deck_names:,
        model_ids:,
        note_rows:,
        card_rows:
      )
        config = validated_deck.deck_source.config
        db = SQLite3::Database.new(collection_path)

        configure_build_database(db)
        db.transaction do
          ANKI_COLLECTION_SCHEMA.each { |statement| db.execute(statement) }
          insert_collection_row(db, config, deck_names, model_ids)
          insert_note_rows(db, note_rows)
          insert_card_rows(db, card_rows)
        end
      ensure
        db&.close
      end

      def configure_build_database(db)
        db.execute('PRAGMA journal_mode = MEMORY')
        db.execute('PRAGMA synchronous = OFF')
        db.execute('PRAGMA temp_store = MEMORY')
      end

      def insert_collection_row(db, config, deck_names, model_ids)
        statement = db.prepare('INSERT INTO col VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
        statement.execute(*collection_row(config, deck_names, model_ids))
      ensure
        statement&.close
      end

      def insert_note_rows(db, note_rows)
        statement = db.prepare('INSERT INTO notes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
        note_rows.each { |row| statement.execute(*row) }
      ensure
        statement&.close
      end

      def insert_card_rows(db, card_rows)
        statement = db.prepare(
          'INSERT INTO cards VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        )
        card_rows.each { |row| statement.execute(*row) }
      ensure
        statement&.close
      end

      def collection_row(config, deck_names, model_ids)
        timestamp = Time.now.to_i
        [
          1,
          timestamp,
          timestamp,
          timestamp,
          11,
          0,
          0,
          0,
          '{}',
          JSON.generate(models_payload(config, model_ids)),
          JSON.generate(decks_payload(deck_names)),
          JSON.generate(deck_config_payload),
          '{}'
        ]
      end

      def models_payload(config, model_ids)
        model_ids.each_with_object({}) do |(deck_name, model_id), payload|
          deck_id = deterministic_integer("deck:#{deck_name}")

          payload[model_id.to_s] = {
            id: model_id,
            name: deck_name,
            type: 0,
            mod: Time.now.to_i,
            usn: 0,
            sortf: 0,
            did: deck_id,
            css: config.css || DEFAULT_MODEL_CSS,
            latexPre: DEFAULT_LATEX_PRE,
            latexPost: DEFAULT_LATEX_POST,
            latexsvg: false,
            req: required_fields_payload(config),
            tags: [],
            vers: [],
            tmpls: template_payloads(config, deck_id),
            flds: field_payloads(config)
          }
        end
      end

      def decks_payload(deck_names)
        timestamp = Time.now.to_i

        deck_names.each_with_object({}) do |deck_name, payload|
          deck_id = deterministic_integer("deck:#{deck_name}")
          payload[deck_id.to_s] = {
            id: deck_id,
            name: deck_name,
            mod: timestamp,
            usn: 0,
            desc: '',
            dyn: 0,
            collapsed: false,
            browserCollapsed: false,
            conf: 1,
            extendNew: 0,
            extendRev: 0,
            newToday: [0, 0],
            revToday: [0, 0],
            lrnToday: [0, 0],
            timeToday: [0, 0]
          }
        end
      end

      def deck_config_payload
        {
          '1' => {
            id: 1,
            name: 'Default',
            mod: Time.now.to_i,
            usn: 0,
            maxTaken: 60,
            autoplay: true,
            timer: 0,
            replayq: true,
            new: {
              bury: true,
              delays: [1, 10],
              initialFactor: 2500,
              ints: [1, 4, 7],
              order: 1,
              perDay: 20
            },
            lapse: {
              delays: [10],
              leechAction: 0,
              leechFails: 8,
              minInt: 1,
              mult: 0
            },
            rev: {
              bury: true,
              ease4: 1.3,
              fuzz: 0.05,
              ivlFct: 1,
              maxIvl: 36_500,
              perDay: 200
            }
          }
        }
      end

      def write_apkg(output_path:, collection_path:)
        FileUtils.rm_f(output_path)

        Zip::File.open(output_path, create: true) do |zip_file|
          zip_file.add('collection.anki2', collection_path)
          zip_file.get_output_stream('media') { |stream| stream.write('{}') }
        end
      end

      def merged_tags(global_tags, local_tags)
        (Array(global_tags) + Array(local_tags)).uniq
      end

      def field_value(note, field)
        return note[field].to_s if note.key?(field) && !note[field].nil?

        derived_field_value(note, field)
      end

      def derived_field_value(note, field)
        builder = DERIVED_FIELD_BUILDERS[field]
        return '' unless builder

        builder.call(note, furigana_formatter)
      end

      def format_tags(tags)
        return '' if tags.empty?

        " #{tags.join(' ')} "
      end

      def checksum(value)
        Digest::SHA1.hexdigest(value)[0, 8].to_i(16)
      end

      def deterministic_integer(seed)
        Digest::SHA1.hexdigest(seed)[0, 15].to_i(16)
      end

      def required_fields_payload(config)
        required_indexes = config.required_fields.map do |field|
          config.all_fields.index(field)
        end.compact
        required_indexes = [0] if required_indexes.empty?

        config.cards.each_index.map do |card_index|
          [card_index, 'all', required_indexes]
        end
      end

      def template_payloads(config, _deck_id)
        config.cards.each_with_index.map do |card, index|
          {
            name: card.name,
            ord: index,
            qfmt: card.front,
            afmt: card.back,
            bqfmt: '',
            bafmt: '',
            did: nil,
            bfont: 'Arial',
            bsize: 20
          }
        end
      end

      def field_payloads(config)
        config.all_fields.each_with_index.map do |field, index|
          {
            name: field,
            ord: index,
            sticky: false,
            rtl: false,
            font: 'Arial',
            size: 20,
            media: []
          }
        end
      end

      def note_identity(note:, note_schema:, deck_seed:)
        note_key = note_schema.render_id(note)
        note_id = deterministic_integer("note:#{deck_seed}:#{note_key}")
        guid = Digest::SHA1.hexdigest("guid:#{deck_seed}:#{note_key}")[0, 20]
        [note_id, guid]
      end

      def append_note_source_rows(note_source:, due:, build_context:)
        deck_id = deterministic_integer("deck:#{note_source.deck_name}")

        note_source.notes.each do |note|
          due = append_note_rows(
            note_source: note_source,
            note: note,
            deck_id: deck_id,
            due: due,
            build_context: build_context
          )
        end

        due
      end

      def append_note_rows(note_source:, note:, deck_id:, due:, build_context:)
        config = build_context.fetch(:config)
        active_cards = active_cards(config, note_source, note)
        note_id, guid = note_identity(
          note: note,
          note_schema: config.note_schema,
          deck_seed: build_context.fetch(:deck_seed)
        )
        build_context.fetch(:note_rows) << note_row(
          config: config,
          note: note,
          note_id: note_id,
          model_id: build_context.fetch(:model_ids).fetch(note_source.deck_name),
          guid: guid,
          timestamp: build_context.fetch(:timestamp)
        )

        append_card_rows(
          config: config,
          active_cards: active_cards,
          card_rows: build_context.fetch(:card_rows),
          card_context: {
            guid: guid,
            note_id: note_id,
            deck_id: deck_id,
            due: due,
            timestamp: build_context.fetch(:timestamp)
          }
        )
      end

      def append_card_rows(config:, active_cards:, card_rows:, card_context:)
        due = card_context.fetch(:due)

        active_cards.each do |card|
          ord = config.cards.index(card)
          card_rows << card_row(
            card_id: deterministic_integer("card:#{card_context.fetch(:guid)}:#{ord}"),
            note_id: card_context.fetch(:note_id),
            deck_id: card_context.fetch(:deck_id),
            ord: ord,
            due: due,
            timestamp: card_context.fetch(:timestamp)
          )
          due += 1
        end

        due
      end

      def furigana_formatter
        @furigana_formatter ||= FuriganaFormatter.new
      end

      def collection_deck_names(deck_source)
        ([deck_source.config.name] + deck_source.note_sources.flat_map do |note_source|
          deck_hierarchy(note_source.deck_name)
        end).uniq
      end

      def model_ids_by_deck(deck_names)
        deck_names.uniq.each_with_object({}) do |deck_name, model_ids|
          model_ids[deck_name] = deterministic_integer("model:#{deck_name}")
        end
      end

      def deck_hierarchy(deck_name)
        parts = deck_name.split('::')

        parts.each_index.map do |index|
          parts[0..index].join('::')
        end
      end

      def active_cards(config, note_source, note)
        config.cards.select do |card|
          card.default? || (
            source_enabled_card?(note_source, card) &&
            fields_present?(note, card.front_fields)
          )
        end
      end

      def source_enabled_card?(note_source, card)
        note_source.enabled_cards.include?(card.name)
      end

      def fields_present?(note, fields)
        fields.all? do |field|
          !field_value(note, field).strip.empty?
        end
      end
    end
  end
end
