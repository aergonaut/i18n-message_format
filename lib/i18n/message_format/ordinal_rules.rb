# frozen_string_literal: true

module I18n
  module MessageFormat
    # Provides CLDR ordinal plural rules for use with +selectordinal+ arguments.
    #
    # Ordinal rules map a number to a category symbol (+:one+, +:two+, +:few+,
    # +:other+, etc.) according to the Unicode CLDR ordinal plural rules for a
    # given locale.
    #
    # Rules are installed into the active I18n backend under the
    # +i18n.ordinal.rule+ key, where {Formatter} looks for them at runtime.
    #
    # @example Installing rules for English
    #   I18n::MessageFormat::OrdinalRules.install(:en)
    #
    # @example Installing all bundled rules
    #   I18n::MessageFormat::OrdinalRules.install_all
    module OrdinalRules
      # Built-in CLDR ordinal plural rules keyed by locale symbol.
      #
      # Each value is a +Proc+ that accepts an integer +n+ and returns the
      # appropriate plural category symbol.
      #
      # @return [Hash{Symbol => Proc}]
      RULES = {
        en: lambda { |n|
          mod10 = n % 10
          mod100 = n % 100
          if mod10 == 1 && mod100 != 11
            :one
          elsif mod10 == 2 && mod100 != 12
            :two
          elsif mod10 == 3 && mod100 != 13
            :few
          else
            :other
          end
        }
      }.freeze

      # Installs the ordinal plural rule for +locale+ into the active I18n
      # backend.
      #
      # Does nothing if no rule is defined for the given locale.
      #
      # @param locale [Symbol, String] the locale to install (e.g. +:en+)
      # @return [void]
      def self.install(locale)
        rule = RULES[locale.to_sym]
        return unless rule

        ::I18n.backend.store_translations(locale, { i18n: { ordinal: { rule: rule } } })
      end

      # Installs ordinal plural rules for every locale in {RULES}.
      #
      # @return [void]
      def self.install_all
        RULES.each_key { |locale| install(locale) }
      end
    end
  end
end
