# frozen_string_literal: true

module Amgi
  module Application
    class Result
      attr_reader :value, :errors

      def self.success(value)
        new(success: true, value: value, errors: [])
      end

      def self.failure(errors)
        new(success: false, value: nil, errors: Array(errors))
      end

      def initialize(success:, value:, errors:)
        @success = success
        @value = value
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
