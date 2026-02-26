# frozen_string_literal: true

require "yaml"

module I18n
  module MessageFormat
    class Backend
      include ::I18n::Backend::Base

      def initialize(*glob_patterns)
        @glob_patterns = glob_patterns
        @translations = {}
        @cache = Cache.new
      end

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

      def store_translations(locale, data, options = {})
        @translations[locale] ||= {}
        deep_merge!(@translations[locale], flatten_hash(data))
      end

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

      def available_locales
        @translations.keys
      end

      def initialized?
        !@translations.empty?
      end

      protected

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
