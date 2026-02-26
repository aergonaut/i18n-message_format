# frozen_string_literal: true

module I18n
  module MessageFormat
    # Raised when a placeholder in the pattern has no corresponding argument.
    class MissingArgumentError < Error
      # The name of the missing argument as it appeared in the pattern.
      #
      # @return [String]
      attr_reader :argument_name

      # @param argument_name [String] the name of the missing argument
      def initialize(argument_name)
        @argument_name = argument_name
        super("Missing argument: #{argument_name}")
      end
    end

    # Walks an AST produced by {Parser} and renders a formatted string.
    #
    # Each node type is dispatched to a dedicated format method. Number, date,
    # and time formatting delegate to +I18n.localize+. Plural and ordinal
    # categorisation uses rules registered under +i18n.plural.rule+ /
    # +i18n.ordinal.rule+ in the active I18n backend, falling back to simple
    # one/other logic when no rule is present.
    class Formatter
      # Creates a new formatter.
      #
      # @param nodes [Array] the AST returned by {Parser#parse}
      # @param arguments [Hash] argument values keyed by Symbol
      # @param locale [Symbol, String] locale used for pluralisation and
      #   number/date/time formatting
      def initialize(nodes, arguments, locale)
        @nodes = nodes
        @arguments = arguments
        @locale = locale
      end

      # Renders the AST to a String.
      #
      # @return [String] the fully formatted message
      # @raise [MissingArgumentError] if a required argument is absent from
      #   the arguments hash
      # @raise [Error] if a plural or select branch cannot be resolved
      def format
        format_nodes(@nodes)
      end

      private

      def format_nodes(nodes)
        nodes.map { |node| format_node(node) }.join
      end

      def format_node(node)
        case node
        when Nodes::TextNode
          node.value
        when Nodes::ArgumentNode
          fetch_argument(node.name).to_s
        when Nodes::NumberFormatNode
          format_number(node)
        when Nodes::DateFormatNode
          format_date(node)
        when Nodes::TimeFormatNode
          format_time(node)
        when Nodes::PluralNode
          format_plural(node)
        when Nodes::SelectNode
          format_select(node)
        when Nodes::SelectOrdinalNode
          format_select_ordinal(node)
        else
          raise Error, "Unknown node type: #{node.class}"
        end
      end

      def fetch_argument(name)
        key = name.to_sym
        unless @arguments.key?(key)
          raise MissingArgumentError.new(name)
        end
        @arguments[key]
      end

      def format_number(node)
        value = fetch_argument(node.name)
        ::I18n.localize(value, locale: @locale)
      rescue ::I18n::MissingTranslationData
        value.to_s
      end

      def format_date(node)
        value = fetch_argument(node.name)
        opts = { locale: @locale }
        opts[:format] = node.style.to_sym if node.style
        ::I18n.localize(value, **opts)
      end

      def format_time(node)
        value = fetch_argument(node.name)
        opts = { locale: @locale }
        opts[:format] = node.style.to_sym if node.style
        ::I18n.localize(value, **opts)
      end

      def format_plural(node)
        value = fetch_argument(node.name)
        effective_value = value - node.offset

        # Check exact matches first
        exact_key = :"=#{value}"
        if node.branches.key?(exact_key)
          return format_branch(node.branches[exact_key], effective_value)
        end

        # Use i18n pluralization rules
        category = pluralize_cardinal(effective_value, @locale)
        branch = node.branches[category] || node.branches[:other]
        raise Error, "No matching plural branch for '#{category}'" unless branch

        format_branch(branch, effective_value)
      end

      def format_select(node)
        value = fetch_argument(node.name)
        key = value.to_s.to_sym
        branch = node.branches[key] || node.branches[:other]
        raise Error, "No matching select branch for '#{key}'" unless branch

        format_nodes(branch)
      end

      def format_select_ordinal(node)
        value = fetch_argument(node.name)
        effective_value = value - node.offset

        exact_key = :"=#{value}"
        if node.branches.key?(exact_key)
          return format_branch(node.branches[exact_key], effective_value)
        end

        category = pluralize_ordinal(effective_value, @locale)
        branch = node.branches[category] || node.branches[:other]
        raise Error, "No matching selectordinal branch for '#{category}'" unless branch

        format_branch(branch, effective_value)
      end

      def format_branch(nodes, numeric_value)
        nodes.map do |node|
          if node.is_a?(Nodes::TextNode)
            node.value.gsub("#", numeric_value.to_s)
          else
            format_node(node)
          end
        end.join
      end

      def pluralize_cardinal(count, locale)
        rule = ::I18n.t(:"i18n.plural.rule", locale: locale, default: nil, resolve: false)
        if rule.respond_to?(:call)
          rule.call(count)
        else
          count == 1 ? :one : :other
        end
      end

      def pluralize_ordinal(count, locale)
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: locale, default: nil, resolve: false)
        if rule.respond_to?(:call)
          rule.call(count)
        else
          :other
        end
      end
    end
  end
end
