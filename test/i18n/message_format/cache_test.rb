# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class CacheTest < Minitest::Test
      def test_stores_and_retrieves
        cache = Cache.new(max_size: 10)
        cache.set("key", "value")
        assert_equal "value", cache.get("key")
      end

      def test_returns_nil_for_missing_key
        cache = Cache.new(max_size: 10)
        assert_nil cache.get("missing")
      end

      def test_evicts_least_recently_used
        cache = Cache.new(max_size: 2)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)
        assert_nil cache.get("a")
        assert_equal 2, cache.get("b")
        assert_equal 3, cache.get("c")
      end

      def test_get_refreshes_entry
        cache = Cache.new(max_size: 2)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.get("a")
        cache.set("c", 3)
        assert_equal 1, cache.get("a")
        assert_nil cache.get("b")
        assert_equal 3, cache.get("c")
      end

      def test_fetch_with_block
        cache = Cache.new(max_size: 10)
        result = cache.fetch("key") { "computed" }
        assert_equal "computed", result
        assert_equal "computed", cache.get("key")
      end

      def test_fetch_returns_cached_value
        cache = Cache.new(max_size: 10)
        cache.set("key", "original")
        result = cache.fetch("key") { "new" }
        assert_equal "original", result
      end

      def test_clear
        cache = Cache.new(max_size: 10)
        cache.set("key", "value")
        cache.clear
        assert_nil cache.get("key")
      end
    end
  end
end
