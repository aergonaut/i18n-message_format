# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class NodesTest < Minitest::Test
      def test_text_node
        node = Nodes::TextNode.new("hello")
        assert_equal "hello", node.value
      end

      def test_argument_node
        node = Nodes::ArgumentNode.new("name")
        assert_equal "name", node.name
      end

      def test_number_format_node
        node = Nodes::NumberFormatNode.new("count", "integer")
        assert_equal "count", node.name
        assert_equal "integer", node.style
      end

      def test_number_format_node_default_style
        node = Nodes::NumberFormatNode.new("count")
        assert_equal "count", node.name
        assert_nil node.style
      end

      def test_date_format_node
        node = Nodes::DateFormatNode.new("d", "short")
        assert_equal "d", node.name
        assert_equal "short", node.style
      end

      def test_time_format_node
        node = Nodes::TimeFormatNode.new("t", "short")
        assert_equal "t", node.name
        assert_equal "short", node.style
      end

      def test_plural_node
        branches = { one: [Nodes::TextNode.new("1 item")], other: [Nodes::TextNode.new("# items")] }
        node = Nodes::PluralNode.new("count", branches, 0)
        assert_equal "count", node.name
        assert_equal branches, node.branches
        assert_equal 0, node.offset
      end

      def test_plural_node_default_offset
        branches = { other: [Nodes::TextNode.new("# items")] }
        node = Nodes::PluralNode.new("count", branches)
        assert_equal 0, node.offset
      end

      def test_select_node
        branches = { male: [Nodes::TextNode.new("He")], other: [Nodes::TextNode.new("They")] }
        node = Nodes::SelectNode.new("gender", branches)
        assert_equal "gender", node.name
        assert_equal branches, node.branches
      end

      def test_select_ordinal_node
        branches = { one: [Nodes::TextNode.new("#st")], other: [Nodes::TextNode.new("#th")] }
        node = Nodes::SelectOrdinalNode.new("pos", branches, 0)
        assert_equal "pos", node.name
        assert_equal branches, node.branches
      end
    end
  end
end
