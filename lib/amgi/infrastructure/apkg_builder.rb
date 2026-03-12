# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
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

      def call(validated_deck, out_dir:)
        FileUtils.mkdir_p(out_dir)

        output_path = File.join(out_dir, "#{sanitize(validated_deck.deck_source.config.name)}.apkg")
        note_rows, card_rows = build_rows(validated_deck)

        Dir.mktmpdir('amgi-build') do |tmp_dir|
          collection_path = File.join(tmp_dir, 'collection.anki2')
          build_collection(
            collection_path: collection_path,
            validated_deck: validated_deck,
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
        model_id = deterministic_integer("model:#{deck_seed}")
        deck_id = deterministic_integer("deck:#{deck_seed}")
        timestamp = Time.now.to_i
        due = 1
        note_rows = []
        card_rows = []
        validated_deck.deck_source.note_sources.each do |note_source|
          note_source.notes.each do |note|
            note_id, guid = note_identity(config: config, note: note, deck_seed: deck_seed)
            note_rows << note_row(
              config: config,
              note: note,
              note_id: note_id,
              model_id: model_id,
              guid: guid,
              timestamp: timestamp
            )
            due = append_card_rows(
              config: config,
              note: note,
              card_rows: card_rows,
              card_context: {
                guid: guid,
                note_id: note_id,
                deck_id: deck_id,
                due: due,
                timestamp: timestamp
              }
            )
          end
        end
        [note_rows, card_rows]
      end

      def note_row(config:, note:, note_id:, model_id:, guid:, timestamp:)
        tags = merged_tags(config.global_tags, note['tags'])
        joined_fields = config.all_fields.map { |field| note[field].to_s }.join("\x1F")
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

      def build_collection(collection_path:, validated_deck:, note_rows:, card_rows:)
        config = validated_deck.deck_source.config
        db = SQLite3::Database.new(collection_path)

        ANKI_COLLECTION_SCHEMA.each { |statement| db.execute(statement) }
        db.execute(
          'INSERT INTO col VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          collection_row(config)
        )
        note_rows.each do |row|
          db.execute('INSERT INTO notes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', row)
        end
        card_rows.each do |row|
          db.execute(
            'INSERT INTO cards VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            row
          )
        end
      ensure
        db&.close
      end

      def collection_row(config)
        timestamp = Time.now.to_i
        deck_id = deterministic_integer("deck:#{config.name}")
        model_id = deterministic_integer("model:#{config.name}")
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
          JSON.generate(models_payload(config, model_id)),
          JSON.generate(decks_payload(config, deck_id)),
          JSON.generate(deck_config_payload),
          '{}'
        ]
      end

      def models_payload(config, model_id)
        {
          model_id.to_s => {
            id: model_id,
            name: config.name,
            type: 0,
            mod: Time.now.to_i,
            usn: 0,
            sortf: 0,
            did: deterministic_integer("deck:#{config.name}"),
            css: config.css || DEFAULT_MODEL_CSS,
            latexPre: DEFAULT_LATEX_PRE,
            latexPost: DEFAULT_LATEX_POST,
            latexsvg: false,
            req: required_fields_payload(config),
            tags: [],
            vers: [],
            tmpls: template_payloads(config),
            flds: field_payloads(config)
          }
        }
      end

      def decks_payload(config, deck_id)
        {
          deck_id.to_s => {
            id: deck_id,
            name: config.name,
            mod: Time.now.to_i,
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
        }
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

      def format_tags(tags)
        return '' if tags.empty?

        " #{tags.join(' ')} "
      end

      def checksum(value)
        Digest::SHA1.hexdigest(value)[0, 8].to_i(16)
      end

      def note_signature(config, note)
        field_signature = config.all_fields.map { |field| "#{field}=#{note[field]}" }
        meta_signature = ["tags=#{Array(note['tags']).join(',')}"]

        (field_signature + meta_signature).join('|')
      end

      def deterministic_integer(seed)
        Digest::SHA1.hexdigest(seed)[0, 15].to_i(16)
      end

      def sanitize(name)
        name.gsub(/[^A-Za-z0-9_-]+/, '_')
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

      def template_payloads(config)
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

      def note_identity(config:, note:, deck_seed:)
        signature = note_signature(config, note)
        note_id = deterministic_integer("note:#{deck_seed}:#{signature}")
        guid = Digest::SHA1.hexdigest("guid:#{deck_seed}:#{signature}")[0, 20]
        [note_id, guid]
      end

      def append_card_rows(config:, note:, card_rows:, card_context:)
        due = card_context.fetch(:due)

        active_cards(config, note).each do |card|
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

      def active_cards(config, note)
        config.cards.select do |card|
          card.default? || fields_present?(note, card.front_fields)
        end
      end

      def fields_present?(note, fields)
        fields.all? do |field|
          value = note[field]
          !value.nil? && !value.to_s.strip.empty?
        end
      end
    end
  end
end
