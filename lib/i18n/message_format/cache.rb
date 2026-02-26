# frozen_string_literal: true

module I18n
  module MessageFormat
    # A thread-safe, bounded LRU (Least Recently Used) cache.
    #
    # Used internally to memoize parsed ASTs so the same pattern string is
    # only parsed once. The cache evicts the least recently accessed entry
    # when the maximum size is reached.
    class Cache
      # Creates a new cache instance.
      #
      # @param max_size [Integer] maximum number of entries to retain before
      #   evicting the least recently used entry (default: +1000+)
      def initialize(max_size: 1000)
        @max_size = max_size
        @data = {}
        @mutex = Mutex.new
      end

      # Retrieves the value stored under +key+, updating its recency.
      #
      # @param key [Object] the cache key
      # @return [Object, nil] the cached value, or +nil+ if not found
      def get(key)
        @mutex.synchronize do
          return nil unless @data.key?(key)
          value = @data.delete(key)
          @data[key] = value
          value
        end
      end

      # Stores +value+ under +key+, evicting the LRU entry if necessary.
      #
      # @param key [Object] the cache key
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def set(key, value)
        @mutex.synchronize do
          @data.delete(key) if @data.key?(key)
          @data[key] = value
          evict if @data.size > @max_size
        end
      end

      # Returns the cached value for +key+, computing and storing it on a miss.
      #
      # @param key [Object] the cache key
      # @yield called on a cache miss to compute the value to store
      # @yieldreturn [Object] the value to cache and return
      # @return [Object] the cached or newly computed value
      def fetch(key)
        value = get(key)
        return value unless value.nil? && !@mutex.synchronize { @data.key?(key) }
        value = yield
        set(key, value)
        value
      end

      # Removes all entries from the cache.
      #
      # @return [void]
      def clear
        @mutex.synchronize { @data.clear }
      end

      private

      def evict
        @data.delete(@data.keys.first)
      end
    end
  end
end
