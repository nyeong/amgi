# frozen_string_literal: true

module Amgi
  module Domain
    class BlankFieldDsl
      Segment = Struct.new(:type, :text, :answer, :hint, keyword_init: true) do
        def text?
          type == :text
        end

        def full_text
          text? ? text : answer
        end

        def blank_text
          return text if text?

          hint ? "[#{hint}]" : '[...]'
        end
      end

      Result = Struct.new(:segments, :errors, keyword_init: true) do
        def valid?
          errors.empty?
        end

        def blank_count
          segments.count { |segment| !segment.text? }
        end

        def full_text
          segments.map(&:full_text).join
        end

        def blank_text
          return '' if blank_count.zero?

          segments.map(&:blank_text).join
        end
      end

      def self.parse(source)
        new.parse(source)
      end

      def parse(source)
        text = source.to_s
        segments = []
        errors = []
        index = 0

        while index < text.length
          if text[index, 2] == '[['
            closing_index = text.index(']]', index + 2)
            unless closing_index
              errors << 'Unclosed blank marker.'
              break
            end

            append_blank_segment(
              text[(index + 2)...closing_index],
              segments: segments,
              errors: errors
            )
            index = closing_index + 2
            next
          end

          if text[index, 2] == ']]'
            errors << 'Unexpected closing blank marker.'
            index += 2
            next
          end

          next_index = [text.index('[[', index), text.index(']]', index)].compact.min || text.length
          segments << Segment.new(type: :text, text: text[index...next_index])
          index = next_index
        end

        Result.new(segments: segments, errors: errors)
      end

      private

      def append_blank_segment(body, segments:, errors:)
        if body.empty?
          errors << 'Blank marker body must not be empty.'
          return
        end

        parts = body.split('|', 3)
        if parts.length == 3
          errors << 'Blank marker can contain at most one hint separator (`|`).'
          return
        end

        answer = parts[0]
        hint = parts[1]

        if answer.to_s.empty?
          errors << 'Blank marker answer must not be empty.'
          return
        end

        if parts.length == 2 && hint.to_s.empty?
          errors << 'Blank marker hint must not be empty when `|` is used.'
          return
        end

        segments << Segment.new(type: :blank, answer: answer, hint: hint)
      end
    end
  end
end
