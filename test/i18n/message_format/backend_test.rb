# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class BackendTest < Minitest::Test
      def setup
        @backend = Backend.new(File.expand_path("../../fixtures/mf/*.yml", __dir__))
        @backend.load_translations
        ::I18n.available_locales = [:en]
      end

      def test_translate_simple
        result = @backend.translate(:en, "greeting", name: "Alice")
        assert_equal "Hello Alice!", result
      end

      def test_translate_plural
        result = @backend.translate(:en, "items", count: 1)
        assert_equal "1 item", result
      end

      def test_translate_plural_other
        result = @backend.translate(:en, "items", count: 5)
        assert_equal "5 items", result
      end

      def test_translate_select
        result = @backend.translate(:en, "welcome", gender: "female", name: "Alice")
        assert_equal "Welcome Ms. Alice", result
      end

      def test_missing_key_throws_exception
        exception = catch(:exception) do
          @backend.translate(:en, "nonexistent")
        end
        assert_kind_of ::I18n::MissingTranslation, exception
      end

      def test_chain_integration
        simple = ::I18n::Backend::Simple.new
        simple.store_translations(:en, { fallback: "from simple" })
        chain = ::I18n::Backend::Chain.new(@backend, simple)

        result = chain.translate(:en, "greeting", name: "Alice")
        assert_equal "Hello Alice!", result

        result = chain.translate(:en, "fallback")
        assert_equal "from simple", result
      end

      def test_available_locales
        assert_includes @backend.available_locales, :en
      end
    end
  end
end
