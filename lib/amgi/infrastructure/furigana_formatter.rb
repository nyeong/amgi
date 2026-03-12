# frozen_string_literal: true

require 'cgi'

module Amgi
  module Infrastructure
    class FuriganaFormatter
      KANA_CHARACTER_CLASS = '[ぁ-ゖァ-ヺー]'
      KANA_SEGMENT_PATTERN = /([ぁ-ゖァ-ヺー]+)/
      KANJI_PATTERN = /[一-龯々〆ヵヶ]/

      def ruby(text:, reading:)
        raw_text = text.to_s
        raw_reading = normalize_kana(reading.to_s)

        return escape(raw_text) if invalid_ruby_input?(raw_text, raw_reading)

        render_ruby(raw_text, raw_reading) || escape(raw_text)
      end

      def annotate(text:, phrase:, phrase_reading:)
        raw_text = text.to_s
        raw_phrase = phrase.to_s
        ruby_phrase = ruby(text: raw_phrase, reading: phrase_reading)

        return escape(raw_text) if raw_text.empty?
        return escape(raw_text) if raw_phrase.empty? || ruby_phrase == escape(raw_phrase)

        pattern = Regexp.new(Regexp.escape(raw_phrase))
        output = +''
        cursor = 0

        raw_text.to_enum(:scan, pattern).each do
          match = Regexp.last_match
          output << escape(raw_text[cursor...match.begin(0)])
          output << ruby_phrase
          cursor = match.end(0)
        end

        return escape(raw_text) if cursor.zero?

        output << escape(raw_text[cursor..])
        output
      end

      private

      def invalid_ruby_input?(raw_text, raw_reading)
        raw_text.empty? || raw_reading.empty? || !raw_text.match?(KANJI_PATTERN)
      end

      def render_ruby(raw_text, raw_reading)
        tokens = raw_text.split(KANA_SEGMENT_PATTERN).reject(&:empty?)
        remaining = raw_reading
        output = +''

        tokens.each_with_index do |segment, index|
          remaining = consume_segment(
            output: output,
            segment: segment,
            tokens: tokens,
            index: index,
            remaining: remaining
          )
          return nil if remaining.nil?
        end

        return nil unless remaining.empty?

        output
      end

      def consume_segment(output:, segment:, tokens:, index:, remaining:)
        if kana?(segment)
          return consume_kana_segment(output: output, segment: segment, remaining: remaining)
        end

        consume_kanji_segment(
          output: output,
          segment: segment,
          next_kana: tokens[(index + 1)..]&.find { |token| kana?(token) },
          remaining: remaining
        )
      end

      def consume_kana_segment(output:, segment:, remaining:)
        normalized = normalize_kana(segment)
        return nil unless remaining.start_with?(normalized)

        output << escape(segment)
        remaining.delete_prefix(normalized)
      end

      def consume_kanji_segment(output:, segment:, next_kana:, remaining:)
        segment_reading = reading_for_segment(remaining, next_kana)
        return nil if segment_reading.nil? || segment_reading.empty?

        output << %(<ruby>#{escape(segment)}<rt>#{escape(segment_reading)}</rt></ruby>)
        remaining.delete_prefix(segment_reading)
      end

      def reading_for_segment(remaining, next_kana)
        return remaining if next_kana.nil?

        boundary = remaining.index(normalize_kana(next_kana))
        return nil if boundary.nil? || boundary.zero?

        remaining[0...boundary]
      end

      def kana?(text)
        text.match?(/\A#{KANA_CHARACTER_CLASS}+\z/o)
      end

      def normalize_kana(text)
        text.each_char.map do |char|
          codepoint = char.ord
          if codepoint.between?(0x30A1, 0x30F6)
            (codepoint - 0x60).chr(Encoding::UTF_8)
          else
            char
          end
        end.join
      end

      def escape(text)
        CGI.escapeHTML(text.to_s)
      end
    end
  end
end
