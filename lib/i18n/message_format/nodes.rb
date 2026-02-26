# frozen_string_literal: true

module I18n
  module MessageFormat
    module Nodes
      TextNode = Struct.new(:value)
      ArgumentNode = Struct.new(:name)
      NumberFormatNode = Struct.new(:name, :style)
      DateFormatNode = Struct.new(:name, :style)
      TimeFormatNode = Struct.new(:name, :style)
      PluralNode = Struct.new(:name, :branches, :offset) do
        def initialize(name, branches, offset = 0)
          super(name, branches, offset)
        end
      end
      SelectNode = Struct.new(:name, :branches)
      SelectOrdinalNode = Struct.new(:name, :branches, :offset) do
        def initialize(name, branches, offset = 0)
          super(name, branches, offset)
        end
      end
    end
  end
end
