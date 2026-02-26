# frozen_string_literal: true

require_relative "message_format/cache"
require_relative "message_format/nodes"
require_relative "message_format/version"

module I18n
  # Top-level namespace for the i18n-message_format gem.
  module MessageFormat
    # Base error class for all errors raised by this gem.
    class Error < StandardError; end
  end
end

require_relative "message_format/parser"
require_relative "message_format/formatter"
require_relative "message_format/backend"
require_relative "message_format/ordinal_rules"

module I18n
  # Provides ICU message format support for the I18n gem.
  #
  # Patterns follow the ICU MessageFormat syntax and support simple argument
  # interpolation as well as `plural`, `select`, and `selectordinal` constructs.
  #
  # @example Simple argument interpolation
  #   I18n::MessageFormat.format("Hello, {name}!", name: "world")
  #   # => "Hello, world!"
  #
  # @example Plural
  #   I18n::MessageFormat.format(
  #     "{count, plural, one {# item} other {# items}}",
  #     count: 3
  #   )
  #   # => "3 items"
  module MessageFormat
    @cache = Cache.new

    class << self
      # Formats an ICU message format pattern with the given arguments.
      #
      # Parsed ASTs are memoized in an internal LRU cache keyed by the pattern
      # string, so repeated calls with the same pattern are efficient.
      #
      # @param pattern [String] an ICU MessageFormat pattern string
      # @param arguments [Hash] a hash of argument names (Symbol or String keys)
      #   to their values. May be omitted in favour of keyword arguments.
      # @param locale [Symbol, String] the locale to use for pluralisation and
      #   number/date/time localisation. Defaults to {I18n.locale}.
      # @param kwargs [Hash] keyword arguments merged into +arguments+ when
      #   +arguments+ is empty.
      # @return [String] the formatted message
      # @raise [ParseError] if +pattern+ contains a syntax error
      # @raise [MissingArgumentError] if a placeholder in +pattern+ has no
      #   corresponding entry in +arguments+
      def format(pattern, arguments = {}, locale: ::I18n.locale, **kwargs)
        arguments = kwargs if arguments.empty? && !kwargs.empty?
        nodes = @cache.fetch(pattern) do
          Parser.new(pattern).parse
        end
        Formatter.new(nodes, arguments, locale).format
      end

      # Clears the internal parse-result cache.
      #
      # Useful in tests or whenever you need to reclaim memory.
      #
      # @return [void]
      def clear_cache!
        @cache.clear
      end
    end
  end
end
