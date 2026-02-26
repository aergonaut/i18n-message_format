# frozen_string_literal: true

require "test_helper"
require "date"

module I18n
  module MessageFormat
    class IntegrationTest < Minitest::Test
      def setup
        @simple = ::I18n::Backend::Simple.new
        @mf = Backend.new(File.expand_path("../../fixtures/mf/*.yml", __dir__))
        ::I18n.backend = ::I18n::Backend::Chain.new(@mf, @simple)
        @mf.load_translations

        @simple.store_translations(:en, { simple_key: "I am simple" })
        @simple.store_translations(:en, {
          date: {
            formats: { short: "%b %d", default: "%Y-%m-%d" },
            abbr_month_names: [nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
            month_names: [nil, "January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"],
            abbr_day_names: %w[Sun Mon Tue Wed Thu Fri Sat],
            day_names: %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday],
            order: [:year, :month, :day]
          },
          time: { formats: { short: "%H:%M", default: "%Y-%m-%d %H:%M:%S" } }
        })

        # Install French plural rule
        @simple.store_translations(:fr, {
          i18n: {
            plural: {
              rule: lambda { |n| n >= 0 && n < 2 ? :one : :other }
            }
          }
        })

        ::I18n.available_locales = [:en, :fr]
      end

      def test_mf_key_resolved
        assert_equal "Hello Alice!", ::I18n.t("greeting", name: "Alice")
      end

      def test_simple_key_falls_through
        assert_equal "I am simple", ::I18n.t("simple_key")
      end

      def test_plural_english
        assert_equal "1 item", ::I18n.t("items", count: 1)
        assert_equal "5 items", ::I18n.t("items", count: 5)
      end

      def test_plural_french
        assert_equal "1 article", ::I18n.t("items", count: 1, locale: :fr)
        assert_equal "5 articles", ::I18n.t("items", count: 5, locale: :fr)
      end

      def test_complex_nested_message
        pattern = "{gender, select, male {{count, plural, one {He has # item} other {He has # items}}} female {{count, plural, one {She has # item} other {She has # items}}} other {{count, plural, one {They have # item} other {They have # items}}}}"
        result = I18n::MessageFormat.format(pattern, gender: "female", count: 3)
        assert_equal "She has 3 items", result
      end

      def test_date_in_message
        pattern = "Updated on {d, date, short}"
        result = I18n::MessageFormat.format(pattern, d: ::Date.new(2026, 3, 15))
        assert_equal "Updated on Mar 15", result
      end

      def test_escaped_braces
        result = I18n::MessageFormat.format("Use '{' and '}' for braces")
        assert_equal "Use { and } for braces", result
      end

      def test_escaped_single_quote
        result = I18n::MessageFormat.format("it''s {name}''s", name: "Alice")
        assert_equal "it's Alice's", result
      end
    end
  end
end
