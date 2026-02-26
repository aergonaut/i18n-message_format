# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class ParserTest < Minitest::Test
      # Task 3: Literal text and simple arguments
      def test_plain_text
        nodes = Parser.new("hello world").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::TextNode, nodes[0]
        assert_equal "hello world", nodes[0].value
      end

      def test_empty_string
        nodes = Parser.new("").parse
        assert_equal 0, nodes.length
      end

      def test_simple_argument
        nodes = Parser.new("{name}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::ArgumentNode, nodes[0]
        assert_equal "name", nodes[0].name
      end

      def test_text_with_argument
        nodes = Parser.new("Hello {name}!").parse
        assert_equal 3, nodes.length
        assert_instance_of Nodes::TextNode, nodes[0]
        assert_equal "Hello ", nodes[0].value
        assert_instance_of Nodes::ArgumentNode, nodes[1]
        assert_equal "name", nodes[1].name
        assert_instance_of Nodes::TextNode, nodes[2]
        assert_equal "!", nodes[2].value
      end

      def test_multiple_arguments
        nodes = Parser.new("{first} and {second}").parse
        assert_equal 3, nodes.length
        assert_instance_of Nodes::ArgumentNode, nodes[0]
        assert_instance_of Nodes::TextNode, nodes[1]
        assert_instance_of Nodes::ArgumentNode, nodes[2]
      end

      def test_escaped_single_quote
        nodes = Parser.new("it''s").parse
        assert_equal 1, nodes.length
        assert_equal "it's", nodes[0].value
      end

      def test_escaped_open_brace
        nodes = Parser.new("'{' literal").parse
        assert_equal 1, nodes.length
        assert_equal "{ literal", nodes[0].value
      end

      def test_escaped_close_brace
        nodes = Parser.new("literal '}'").parse
        assert_equal 1, nodes.length
        assert_equal "literal }", nodes[0].value
      end

      def test_unclosed_brace_raises_parse_error
        assert_raises(ParseError) do
          Parser.new("{name").parse
        end
      end

      # Task 4: Formatted arguments
      def test_number_format
        nodes = Parser.new("{count, number}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::NumberFormatNode, nodes[0]
        assert_equal "count", nodes[0].name
        assert_nil nodes[0].style
      end

      def test_number_format_with_style
        nodes = Parser.new("{count, number, integer}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::NumberFormatNode, nodes[0]
        assert_equal "integer", nodes[0].style
      end

      def test_date_format
        nodes = Parser.new("{d, date}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::DateFormatNode, nodes[0]
        assert_equal "d", nodes[0].name
        assert_nil nodes[0].style
      end

      def test_date_format_with_style
        nodes = Parser.new("{d, date, short}").parse
        assert_instance_of Nodes::DateFormatNode, nodes[0]
        assert_equal "short", nodes[0].style
      end

      def test_time_format
        nodes = Parser.new("{t, time}").parse
        assert_instance_of Nodes::TimeFormatNode, nodes[0]
      end

      def test_time_format_with_style
        nodes = Parser.new("{t, time, short}").parse
        assert_instance_of Nodes::TimeFormatNode, nodes[0]
        assert_equal "short", nodes[0].style
      end

      def test_unknown_type_raises_parse_error
        assert_raises(ParseError) do
          Parser.new("{x, unknown}").parse
        end
      end

      # Task 5: Plural, select, selectordinal
      def test_plural
        nodes = Parser.new("{count, plural, one {# item} other {# items}}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::PluralNode, nodes[0]
        assert_equal "count", nodes[0].name
        assert_includes nodes[0].branches, :one
        assert_includes nodes[0].branches, :other
        assert_equal 0, nodes[0].offset
      end

      def test_plural_with_exact_match
        nodes = Parser.new("{count, plural, =0 {none} one {one} other {many}}").parse
        node = nodes[0]
        assert_includes node.branches, :"=0"
        assert_includes node.branches, :one
        assert_includes node.branches, :other
      end

      def test_plural_with_offset
        nodes = Parser.new("{count, plural, offset:1 one {# item} other {# items}}").parse
        assert_equal 1, nodes[0].offset
      end

      def test_select
        nodes = Parser.new("{gender, select, male {He} female {She} other {They}}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::SelectNode, nodes[0]
        assert_equal "gender", nodes[0].name
        assert_includes nodes[0].branches, :male
        assert_includes nodes[0].branches, :female
        assert_includes nodes[0].branches, :other
      end

      def test_selectordinal
        nodes = Parser.new("{pos, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}").parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::SelectOrdinalNode, nodes[0]
        assert_equal "pos", nodes[0].name
      end

      def test_nested_plural_in_select
        pattern = "{gender, select, male {{count, plural, one {He has # item} other {He has # items}}} other {{count, plural, one {They have # item} other {They have # items}}}}"
        nodes = Parser.new(pattern).parse
        assert_equal 1, nodes.length
        assert_instance_of Nodes::SelectNode, nodes[0]
        male_branch = nodes[0].branches[:male]
        assert_instance_of Nodes::PluralNode, male_branch[0]
      end
    end
  end
end
