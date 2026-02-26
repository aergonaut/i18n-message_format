# frozen_string_literal: true

module I18n
  module MessageFormat
    class Cache
      def initialize(max_size: 1000)
        @max_size = max_size
        @data = {}
        @mutex = Mutex.new
      end

      def get(key)
        @mutex.synchronize do
          return nil unless @data.key?(key)
          value = @data.delete(key)
          @data[key] = value
          value
        end
      end

      def set(key, value)
        @mutex.synchronize do
          @data.delete(key) if @data.key?(key)
          @data[key] = value
          evict if @data.size > @max_size
        end
      end

      def fetch(key)
        value = get(key)
        return value unless value.nil? && !@mutex.synchronize { @data.key?(key) }
        value = yield
        set(key, value)
        value
      end

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
