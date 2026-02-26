# frozen_string_literal: true

module I18n
  module MessageFormat
    module OrdinalRules
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

      def self.install(locale)
        rule = RULES[locale.to_sym]
        return unless rule

        ::I18n.backend.store_translations(locale, { i18n: { ordinal: { rule: rule } } })
      end

      def self.install_all
        RULES.each_key { |locale| install(locale) }
      end
    end
  end
end
