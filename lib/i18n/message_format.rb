# frozen_string_literal: true

require_relative "message_format/cache"
require_relative "message_format/nodes"
require_relative "message_format/version"

module I18n
  module MessageFormat
    class Error < StandardError; end
  end
end

require_relative "message_format/parser"
require_relative "message_format/formatter"
require_relative "message_format/backend"
require_relative "message_format/ordinal_rules"

module I18n
  module MessageFormat
    @cache = Cache.new

    class << self
      def format(pattern, arguments = {}, locale: ::I18n.locale, **kwargs)
        arguments = kwargs if arguments.empty? && !kwargs.empty?
        nodes = @cache.fetch(pattern) do
          Parser.new(pattern).parse
        end
        Formatter.new(nodes, arguments, locale).format
      end

      def clear_cache!
        @cache.clear
      end
    end
  end
end
