# frozen_string_literal: true

module I18n
  module MessageFormat
    # Namespace for the AST node types produced by {Parser}.
    #
    # Each node is a +Struct+ whose members correspond to the semantic
    # components of the ICU MessageFormat construct it represents.
    module Nodes
      # A literal text segment that requires no further processing.
      #
      # @!attribute [rw] value
      #   @return [String] the literal text content
      TextNode = Struct.new(:value)

      # A simple argument placeholder, e.g. +{name}+.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name as it appears in the pattern
      ArgumentNode = Struct.new(:name)

      # A +{name, number}+ or +{name, number, style}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] style
      #   @return [String, nil] optional number format style (e.g. +"integer"+)
      NumberFormatNode = Struct.new(:name, :style)

      # A +{name, date}+ or +{name, date, style}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] style
      #   @return [String, nil] optional date format style (e.g. +"short"+)
      DateFormatNode = Struct.new(:name, :style)

      # A +{name, time}+ or +{name, time, style}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] style
      #   @return [String, nil] optional time format style (e.g. +"short"+)
      TimeFormatNode = Struct.new(:name, :style)

      # A +{name, plural, ...}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] branches
      #   @return [Hash{Symbol => Array<Nodes::TextNode, ...>}] plural branches
      #     keyed by plural category (e.g. +:one+, +:other+) or exact-value
      #     keys like +:=0+
      # @!attribute [rw] offset
      #   @return [Integer] value subtracted from the argument before
      #     pluralisation (default: +0+)
      PluralNode = Struct.new(:name, :branches, :offset) do
        # @param name [String]
        # @param branches [Hash]
        # @param offset [Integer]
        def initialize(name, branches, offset = 0)
          super(name, branches, offset)
        end
      end

      # A +{name, select, ...}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] branches
      #   @return [Hash{Symbol => Array}] select branches keyed by selector
      #     value, with an optional +:other+ fallback
      SelectNode = Struct.new(:name, :branches)

      # A +{name, selectordinal, ...}+ argument.
      #
      # @!attribute [rw] name
      #   @return [String] the argument name
      # @!attribute [rw] branches
      #   @return [Hash{Symbol => Array}] ordinal plural branches keyed by
      #     ordinal category (e.g. +:one+, +:two+, +:few+, +:other+) or
      #     exact-value keys like +:=1+
      # @!attribute [rw] offset
      #   @return [Integer] value subtracted from the argument before
      #     categorisation (default: +0+)
      SelectOrdinalNode = Struct.new(:name, :branches, :offset) do
        # @param name [String]
        # @param branches [Hash]
        # @param offset [Integer]
        def initialize(name, branches, offset = 0)
          super(name, branches, offset)
        end
      end
    end
  end
end
