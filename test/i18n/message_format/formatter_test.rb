# frozen_string_literal: true

require "test_helper"
require "date"

module I18n
  module MessageFormat
    class FormatterTest < Minitest::Test
      def setup
        ::I18n.backend = ::I18n::Backend::Simple.new
        ::I18n.available_locales = [:en]
        ::I18n.locale = :en
        ::I18n.backend.store_translations(:en, {
          date: {
            formats: { short: "%b %d" },
            abbr_month_names: [nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          },
          time: { formats: { short: "%H:%M" } }
        })
      end

      # Task 6: Text and simple arguments
      def test_text_only
        result = Formatter.new([Nodes::TextNode.new("hello")], {}, :en).format
        assert_equal "hello", result
      end

      def test_simple_argument
        nodes = [
          Nodes::TextNode.new("Hello "),
          Nodes::ArgumentNode.new("name"),
          Nodes::TextNode.new("!")
        ]
        result = Formatter.new(nodes, { name: "Alice" }, :en).format
        assert_equal "Hello Alice!", result
      end

      def test_missing_argument_raises
        nodes = [Nodes::ArgumentNode.new("name")]
        assert_raises(MissingArgumentError) do
          Formatter.new(nodes, {}, :en).format
        end
      end

      def test_argument_calls_to_s
        nodes = [Nodes::ArgumentNode.new("count")]
        result = Formatter.new(nodes, { count: 42 }, :en).format
        assert_equal "42", result
      end

      # Task 7: Plural and select
      def test_plural_one
        nodes = Parser.new("{count, plural, one {# item} other {# items}}").parse
        result = Formatter.new(nodes, { count: 1 }, :en).format
        assert_equal "1 item", result
      end

      def test_plural_other
        nodes = Parser.new("{count, plural, one {# item} other {# items}}").parse
        result = Formatter.new(nodes, { count: 5 }, :en).format
        assert_equal "5 items", result
      end

      def test_plural_exact_match
        nodes = Parser.new("{count, plural, =0 {no items} one {# item} other {# items}}").parse
        result = Formatter.new(nodes, { count: 0 }, :en).format
        assert_equal "no items", result
      end

      def test_plural_with_offset
        nodes = Parser.new("{count, plural, offset:1 =0 {nobody} =1 {just {name}} one {{name} and # other} other {{name} and # others}}").parse
        result = Formatter.new(nodes, { count: 3, name: "Alice" }, :en).format
        assert_equal "Alice and 2 others", result
      end

      def test_select
        nodes = Parser.new("{gender, select, male {He} female {She} other {They}}").parse
        result = Formatter.new(nodes, { gender: "female" }, :en).format
        assert_equal "She", result
      end

      def test_select_falls_back_to_other
        nodes = Parser.new("{gender, select, male {He} female {She} other {They}}").parse
        result = Formatter.new(nodes, { gender: "nonbinary" }, :en).format
        assert_equal "They", result
      end

      # Task 8: Number, date, time via I18n.l
      def test_date_format
        nodes = Parser.new("{d, date, short}").parse
        result = Formatter.new(nodes, { d: ::Date.new(2026, 1, 15) }, :en).format
        assert_equal "Jan 15", result
      end

      def test_time_format
        nodes = Parser.new("{t, time, short}").parse
        result = Formatter.new(nodes, { t: ::Time.new(2026, 1, 15, 14, 30, 0) }, :en).format
        assert_equal "14:30", result
      end
    end
  end
end
