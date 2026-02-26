# frozen_string_literal: true

require "yaml"

module I18n
  module MessageFormat
    # An I18n backend that parses and formats ICU MessageFormat patterns.
    #
    # {Backend} implements +I18n::Backend::Base+ and can be used standalone or
    # chained with other backends via +I18n::Backend::Chain+. Translation
    # values that are Strings are treated as ICU MessageFormat patterns; any
    # extra options passed to {#translate} (beyond +scope+, +default+, and
    # +separator+) are forwarded as format arguments.
    #
    # Non-String values (e.g. arrays or hashes used as scopes) are returned
    # as-is without formatting.
    #
    # @example Standalone usage
    #   backend = I18n::MessageFormat::Backend.new("config/locales/**/*.yml")
    #   I18n.backend = backend
    #   backend.load_translations
    #   I18n.t("greeting", name: "Alice")  # => "Hello, Alice!"
    #
    # @example Chained with the default Simple backend
    #   I18n.backend = I18n::Backend::Chain.new(
    #     I18n::MessageFormat::Backend.new("config/locales/**/*.yml"),
    #     I18n.backend
    #   )
    class Backend
      include ::I18n::Backend::Base

      # Creates a new backend that will load translations from the given
      # file glob patterns.
      #
      # @param glob_patterns [Array<String>] one or more glob patterns passed
      #   to +Dir.glob+ to locate YAML translation files
      def initialize(*glob_patterns)
        @glob_patterns = glob_patterns
        @translations = {}
        @cache = Cache.new
      end

      # Loads translations from all YAML files matching the glob patterns
      # provided at construction time.
      #
      # Files are expected to be YAML documents whose top-level keys are locale
      # codes (e.g. +en+, +fr+) mapping to a hash of translation keys and
      # values.
      #
      # @return [void]
      def load_translations
        @glob_patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            data = YAML.safe_load_file(file, permitted_classes: [Symbol])
            data.each do |locale, translations|
              store_translations(locale.to_sym, translations)
            end
          end
        end
      end

      # Merges +data+ into the in-memory translation store for +locale+.
      #
      # Nested hashes are flattened into dot-separated keys (e.g.
      # +{ greeting: { hello: "Hi" } }+ becomes +{ :"greeting.hello" => "Hi" }+)
      # before being merged.
      #
      # @param locale [Symbol, String] the locale to store translations for
      # @param data [Hash] a (possibly nested) hash of translation keys/values
      # @param options [Hash] currently unused; reserved for compatibility with
      #   +I18n::Backend::Base+
      # @return [void]
      def store_translations(locale, data, options = {})
        @translations[locale] ||= {}
        deep_merge!(@translations[locale], flatten_hash(data))
      end

      # Looks up and formats the translation identified by +key+ for +locale+.
      #
      # String values are interpreted as ICU MessageFormat patterns and
      # formatted with any extra keys in +options+ as arguments. Non-string
      # values are returned unchanged.
      #
      # Throws +:exception+ with an +I18n::MissingTranslation+ object when the
      # key is not found, which is the conventional signal for +I18n::Backend::Base+
      # to trigger the default/fallback mechanism.
      #
      # @param locale [Symbol, String] the locale to translate for
      # @param key [Symbol, String] the translation key
      # @param options [Hash] format arguments plus the standard I18n options
      #   (+:scope+, +:default+, +:separator+)
      # @return [String, Object] the formatted translation string, or the raw
      #   value if it is not a String
      # @raise [I18n::MissingTranslation] (via +throw+) when the key is absent
      def translate(locale, key, options = {})
        pattern = lookup(locale, key, options[:scope], options)

        if pattern.nil?
          throw(:exception, ::I18n::MissingTranslation.new(locale, key, options))
        end

        return pattern unless pattern.is_a?(String)

        arguments = options.reject { |k, _| [:scope, :default, :separator].include?(k) }
        nodes = @cache.fetch(pattern) { Parser.new(pattern).parse }
        Formatter.new(nodes, arguments, locale).format
      end

      # Returns the list of locales for which translations have been stored.
      #
      # @return [Array<Symbol>]
      def available_locales
        @translations.keys
      end

      # Returns +true+ if any translations have been loaded into the backend.
      #
      # @return [Boolean]
      def initialized?
        !@translations.empty?
      end

      protected

      # Looks up a translation value by locale and key.
      #
      # @param locale [Symbol, String] the locale to look up
      # @param key [Symbol, String] the translation key
      # @param scope [Array, Symbol, nil] optional scope prepended to the key
      # @param options [Hash] may include +:separator+ to override the default
      #   key separator
      # @return [Object, nil] the translation value, or +nil+ if not found
      def lookup(locale, key, scope = [], options = {})
        keys = ::I18n.normalize_keys(locale, key, scope, options[:separator])
        keys.shift # remove locale

        result = @translations[locale]
        return nil unless result

        keys.each do |k|
          return nil unless result.is_a?(Hash)
          result = result[k] || result[k.to_s]
          return nil if result.nil?
        end

        result
      end

      private

      def flatten_hash(hash, prefix = nil)
        result = {}
        hash.each do |key, value|
          full_key = prefix ? :"#{prefix}.#{key}" : key.to_sym
          if value.is_a?(Hash)
            result.merge!(flatten_hash(value, full_key))
          else
            result[full_key] = value
          end
        end
        result
      end

      def deep_merge!(base, override)
        override.each do |key, value|
          base[key] = value
        end
        base
      end
    end
  end
end
