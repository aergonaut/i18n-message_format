# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class FormatTest < Minitest::Test
      def test_simple_format
        result = I18n::MessageFormat.format("Hello {name}!", name: "World")
        assert_equal "Hello World!", result
      end

      def test_plural_format
        result = I18n::MessageFormat.format(
          "{count, plural, one {# item} other {# items}}",
          count: 3
        )
        assert_equal "3 items", result
      end

      def test_caches_parsed_patterns
        pattern = "Hello {name}!"
        I18n::MessageFormat.format(pattern, name: "A")
        I18n::MessageFormat.format(pattern, name: "B")
        assert_equal "Hello C!", I18n::MessageFormat.format(pattern, name: "C")
      end

      def test_format_with_locale
        result = I18n::MessageFormat.format("Hello {name}!", { name: "World" }, locale: :en)
        assert_equal "Hello World!", result
      end
    end
  end
end
