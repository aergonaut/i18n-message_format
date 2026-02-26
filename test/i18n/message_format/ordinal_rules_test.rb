# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class OrdinalRulesTest < Minitest::Test
      def setup
        ::I18n.backend = ::I18n::Backend::Simple.new
        OrdinalRules.install(:en)
      end

      def test_english_ordinal_1st
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :one, rule.call(1)
      end

      def test_english_ordinal_2nd
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :two, rule.call(2)
      end

      def test_english_ordinal_3rd
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :few, rule.call(3)
      end

      def test_english_ordinal_4th
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :other, rule.call(4)
      end

      def test_english_ordinal_11th
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :other, rule.call(11)
      end

      def test_english_ordinal_21st
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :one, rule.call(21)
      end

      def test_selectordinal_integration
        OrdinalRules.install(:en)
        result = I18n::MessageFormat.format(
          "{pos, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",
          pos: 3,
          locale: :en
        )
        assert_equal "3rd", result
      end
    end
  end
end
