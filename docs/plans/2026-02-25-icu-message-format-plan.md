# ICU Message Format Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Ruby gem that adds full ICU Message Format support to the ruby-i18n gem via a chainable backend.

**Architecture:** Three layers — a pure Ruby recursive descent parser (string to AST), a formatter that walks the AST using i18n's existing localization and pluralization infrastructure, and a chainable I18n backend that loads Message Format strings from separate YAML files. An LRU cache sits between backend and parser.

**Tech Stack:** Ruby >= 3.2, i18n gem (runtime), minitest (testing)

---

### Task 1: Project Setup — Gemspec, Dependencies, and Test Harness

**Files:**
- Modify: `i18n-message_format.gemspec`
- Modify: `Gemfile`
- Modify: `Rakefile`
- Create: `test/test_helper.rb`

**Step 1: Update the gemspec with real metadata and i18n dependency**

```ruby
# i18n-message_format.gemspec
# frozen_string_literal: true

require_relative "lib/i18n/message_format/version"

Gem::Specification.new do |spec|
  spec.name = "i18n-message_format"
  spec.version = I18n::MessageFormat::VERSION
  spec.authors = ["Chris Fung"]
  spec.email = ["aergonaut@gmail.com"]

  spec.summary = "ICU Message Format support for Ruby i18n"
  spec.description = "A pure Ruby implementation of ICU Message Format that integrates with the ruby-i18n gem via a chainable backend."
  spec.homepage = "https://github.com/aergonaut/i18n-message_format"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/aergonaut/i18n-message_format"
  spec.metadata["changelog_uri"] = "https://github.com/aergonaut/i18n-message_format/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "i18n", ">= 1.0"
end
```

**Step 2: Update Gemfile to add minitest**

```ruby
# Gemfile
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "irb"
gem "rake", "~> 13.0"
gem "minitest", "~> 5.0"
```

**Step 3: Update Rakefile to run tests**

```ruby
# Rakefile
# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
```

**Step 4: Create test helper**

```ruby
# test/test_helper.rb
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "i18n/message_format"
require "minitest/autorun"
```

**Step 5: Run bundle install and verify rake works**

Run: `bundle install && bundle exec rake test`
Expected: 0 tests, 0 failures (no test files yet)

**Step 6: Commit**

```bash
git add -A
git commit -m "Set up project: gemspec, dependencies, test harness"
```

---

### Task 2: AST Node Classes

**Files:**
- Create: `lib/i18n/message_format/nodes.rb`
- Create: `test/i18n/message_format/nodes_test.rb`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Write the failing test**

```ruby
# test/i18n/message_format/nodes_test.rb
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/nodes_test.rb`
Expected: FAIL — `Nodes` not defined

**Step 3: Write minimal implementation**

```ruby
# lib/i18n/message_format/nodes.rb
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
```

**Step 4: Update the main require file**

```ruby
# lib/i18n/message_format.rb
# frozen_string_literal: true

require_relative "message_format/version"
require_relative "message_format/nodes"

module I18n
  module MessageFormat
    class Error < StandardError; end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/nodes_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add AST node classes"
```

---

### Task 3: Parser — Literal Text and Simple Arguments

**Files:**
- Create: `lib/i18n/message_format/parser.rb`
- Create: `test/i18n/message_format/parser_test.rb`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Write the failing tests**

```ruby
# test/i18n/message_format/parser_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class ParserTest < Minitest::Test
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
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/parser_test.rb`
Expected: FAIL — `Parser` not defined

**Step 3: Write minimal implementation**

```ruby
# lib/i18n/message_format/parser.rb
# frozen_string_literal: true

module I18n
  module MessageFormat
    class ParseError < Error
      attr_reader :position

      def initialize(message, position = nil)
        @position = position
        super(position ? "#{message} at position #{position}" : message)
      end
    end

    class Parser
      def initialize(pattern)
        @pattern = pattern
        @pos = 0
      end

      def parse
        nodes = parse_message
        nodes
      end

      private

      def parse_message(terminate_on = nil)
        nodes = []

        until eof?
          char = current_char

          if terminate_on&.include?(char)
            break
          elsif char == "{"
            @pos += 1
            nodes << parse_argument
          elsif char == "}"
            raise ParseError.new("Unexpected }", @pos)
          elsif char == "'"
            nodes << parse_quoted_or_literal(nodes)
          else
            nodes << parse_text(terminate_on)
          end
        end

        merge_adjacent_text(nodes)
      end

      def parse_text(terminate_on = nil)
        start = @pos
        while !eof? && current_char != "{" && current_char != "}" && current_char != "'" && !terminate_on&.include?(current_char)
          @pos += 1
        end
        Nodes::TextNode.new(@pattern[start...@pos])
      end

      def parse_quoted_or_literal(preceding_nodes)
        @pos += 1 # skip opening quote

        if eof?
          Nodes::TextNode.new("'")
        elsif current_char == "'"
          # '' => literal single quote
          @pos += 1
          Nodes::TextNode.new("'")
        elsif current_char == "{" || current_char == "}"
          # '{ or '} => literal brace, read until closing quote or end
          text = +""
          while !eof? && current_char != "'"
            text << current_char
            @pos += 1
          end
          @pos += 1 unless eof? # skip closing quote
          Nodes::TextNode.new(text)
        else
          # standalone quote, treat as literal
          Nodes::TextNode.new("'")
        end
      end

      def parse_argument
        skip_whitespace
        name = parse_identifier
        skip_whitespace

        if eof?
          raise ParseError.new("Unclosed argument", @pos)
        end

        if current_char == "}"
          @pos += 1
          return Nodes::ArgumentNode.new(name)
        end

        if current_char == ","
          @pos += 1
          skip_whitespace
          return parse_typed_argument(name)
        end

        raise ParseError.new("Expected ',' or '}' in argument", @pos)
      end

      def parse_typed_argument(name)
        type = parse_identifier
        skip_whitespace

        case type
        when "number"
          parse_number_arg(name)
        when "date"
          parse_date_arg(name)
        when "time"
          parse_time_arg(name)
        when "plural"
          parse_plural_arg(name)
        when "select"
          parse_select_arg(name)
        when "selectordinal"
          parse_select_ordinal_arg(name)
        else
          raise ParseError.new("Unknown argument type '#{type}'", @pos)
        end
      end

      def parse_number_arg(name)
        if current_char == "}"
          @pos += 1
          return Nodes::NumberFormatNode.new(name)
        end

        expect(",")
        skip_whitespace
        style = parse_identifier
        skip_whitespace
        expect("}")
        Nodes::NumberFormatNode.new(name, style)
      end

      def parse_date_arg(name)
        if current_char == "}"
          @pos += 1
          return Nodes::DateFormatNode.new(name)
        end

        expect(",")
        skip_whitespace
        style = parse_identifier
        skip_whitespace
        expect("}")
        Nodes::DateFormatNode.new(name, style)
      end

      def parse_time_arg(name)
        if current_char == "}"
          @pos += 1
          return Nodes::TimeFormatNode.new(name)
        end

        expect(",")
        skip_whitespace
        style = parse_identifier
        skip_whitespace
        expect("}")
        Nodes::TimeFormatNode.new(name, style)
      end

      def parse_plural_arg(name)
        expect(",")
        skip_whitespace

        offset = 0
        if @pattern[@pos..].start_with?("offset:")
          @pos += 7
          skip_whitespace
          offset = parse_number
          skip_whitespace
        end

        branches = parse_branches
        expect("}")
        Nodes::PluralNode.new(name, branches, offset)
      end

      def parse_select_arg(name)
        expect(",")
        skip_whitespace
        branches = parse_branches
        expect("}")
        Nodes::SelectNode.new(name, branches)
      end

      def parse_select_ordinal_arg(name)
        expect(",")
        skip_whitespace

        offset = 0
        if @pattern[@pos..].start_with?("offset:")
          @pos += 7
          skip_whitespace
          offset = parse_number
          skip_whitespace
        end

        branches = parse_branches
        expect("}")
        Nodes::SelectOrdinalNode.new(name, branches, offset)
      end

      def parse_branches
        branches = {}

        while !eof? && current_char != "}"
          skip_whitespace
          break if eof? || current_char == "}"

          key = parse_branch_key
          skip_whitespace
          expect("{")
          value = parse_message("}")
          expect("}")
          skip_whitespace

          branches[key] = value
        end

        branches
      end

      def parse_branch_key
        if current_char == "="
          @pos += 1
          :"=#{parse_number}"
        else
          parse_identifier.to_sym
        end
      end

      def parse_identifier
        start = @pos
        while !eof? && identifier_char?(current_char)
          @pos += 1
        end
        raise ParseError.new("Expected identifier", start) if @pos == start
        @pattern[start...@pos]
      end

      def parse_number
        start = @pos
        @pos += 1 if !eof? && current_char == "-"
        while !eof? && current_char.match?(/[0-9]/)
          @pos += 1
        end
        raise ParseError.new("Expected number", start) if @pos == start
        @pattern[start...@pos].to_i
      end

      def identifier_char?(char)
        char.match?(/[a-zA-Z0-9_]/)
      end

      def skip_whitespace
        @pos += 1 while !eof? && current_char.match?(/\s/)
      end

      def expect(char)
        if eof? || current_char != char
          raise ParseError.new("Expected '#{char}'", @pos)
        end
        @pos += 1
      end

      def current_char
        @pattern[@pos]
      end

      def eof?
        @pos >= @pattern.length
      end

      def merge_adjacent_text(nodes)
        merged = []
        nodes.each do |node|
          if node.is_a?(Nodes::TextNode) && merged.last.is_a?(Nodes::TextNode)
            merged.last.value << node.value
          else
            merged << node
          end
        end
        merged
      end
    end
  end
end
```

**Step 4: Update the main require file**

Add `require_relative "message_format/parser"` to `lib/i18n/message_format.rb`.

**Step 5: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/parser_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add parser: literal text, simple arguments, escaping"
```

---

### Task 4: Parser — Formatted Arguments (number, date, time)

**Files:**
- Modify: `test/i18n/message_format/parser_test.rb`
- (Parser already handles these from Task 3, add tests to confirm)

**Step 1: Write the failing tests**

Add to `test/i18n/message_format/parser_test.rb`:

```ruby
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
```

**Step 2: Run tests to verify they pass** (parser already supports these)

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/parser_test.rb`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Add parser tests for formatted arguments (number, date, time)"
```

---

### Task 5: Parser — Plural, Select, SelectOrdinal

**Files:**
- Modify: `test/i18n/message_format/parser_test.rb`

**Step 1: Write the failing tests**

Add to `test/i18n/message_format/parser_test.rb`:

```ruby
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
```

**Step 2: Run tests**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/parser_test.rb`
Expected: All tests PASS (parser already implements these)

**Step 3: Commit**

```bash
git add -A
git commit -m "Add parser tests for plural, select, selectordinal, and nesting"
```

---

### Task 6: Formatter — Text and Simple Arguments

**Files:**
- Create: `lib/i18n/message_format/formatter.rb`
- Create: `test/i18n/message_format/formatter_test.rb`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Write the failing tests**

```ruby
# test/i18n/message_format/formatter_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class FormatterTest < Minitest::Test
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
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/formatter_test.rb`
Expected: FAIL — `Formatter` not defined

**Step 3: Write minimal implementation**

```ruby
# lib/i18n/message_format/formatter.rb
# frozen_string_literal: true

module I18n
  module MessageFormat
    class MissingArgumentError < Error
      attr_reader :argument_name

      def initialize(argument_name)
        @argument_name = argument_name
        super("Missing argument: #{argument_name}")
      end
    end

    class Formatter
      def initialize(nodes, arguments, locale)
        @nodes = nodes
        @arguments = arguments
        @locale = locale
      end

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
```

**Step 4: Update the main require file**

Add `require_relative "message_format/formatter"` to `lib/i18n/message_format.rb`.

**Step 5: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/formatter_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add formatter: text and simple argument nodes"
```

---

### Task 7: Formatter — Plural and Select

**Files:**
- Modify: `test/i18n/message_format/formatter_test.rb`

**Step 1: Write the failing tests**

Add to `test/i18n/message_format/formatter_test.rb`:

```ruby
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
```

**Step 2: Run tests**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/formatter_test.rb`
Expected: All tests PASS (formatter already implements these)

**Step 3: Commit**

```bash
git add -A
git commit -m "Add formatter tests for plural and select"
```

---

### Task 8: Formatter — Number, Date, Time via I18n.l

**Files:**
- Modify: `test/i18n/message_format/formatter_test.rb`

**Step 1: Write the failing tests**

Add to `test/i18n/message_format/formatter_test.rb`:

```ruby
def setup
  ::I18n.backend = ::I18n::Backend::Simple.new
  ::I18n.locale = :en
  ::I18n.backend.store_translations(:en, {
    date: { formats: { short: "%b %d" } },
    time: { formats: { short: "%H:%M" } }
  })
end

def test_date_format
  nodes = Parser.new("{d, date, short}").parse
  result = Formatter.new(nodes, { d: Date.new(2026, 1, 15) }, :en).format
  assert_equal "Jan 15", result
end

def test_time_format
  nodes = Parser.new("{t, time, short}").parse
  result = Formatter.new(nodes, { t: Time.new(2026, 1, 15, 14, 30, 0) }, :en).format
  assert_equal "14:30", result
end
```

**Step 2: Run tests**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/formatter_test.rb`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Add formatter tests for date and time formatting via I18n.l"
```

---

### Task 9: LRU Cache

**Files:**
- Create: `lib/i18n/message_format/cache.rb`
- Create: `test/i18n/message_format/cache_test.rb`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Write the failing tests**

```ruby
# test/i18n/message_format/cache_test.rb
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
        cache.set("c", 3) # should evict "a"
        assert_nil cache.get("a")
        assert_equal 2, cache.get("b")
        assert_equal 3, cache.get("c")
      end

      def test_get_refreshes_entry
        cache = Cache.new(max_size: 2)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.get("a") # refresh "a", so "b" is now LRU
        cache.set("c", 3) # should evict "b"
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/cache_test.rb`
Expected: FAIL — `Cache` not defined

**Step 3: Write minimal implementation**

```ruby
# lib/i18n/message_format/cache.rb
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

          # Move to end (most recently used)
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
```

**Step 4: Update the main require file**

Add `require_relative "message_format/cache"` to `lib/i18n/message_format.rb`.

**Step 5: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/cache_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add thread-safe LRU cache"
```

---

### Task 10: Public API — `I18n::MessageFormat.format`

**Files:**
- Modify: `lib/i18n/message_format.rb`
- Create: `test/i18n/message_format/format_test.rb`

**Step 1: Write the failing tests**

```ruby
# test/i18n/message_format/format_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class FormatTest < Minitest::Test
      def test_simple_format
        result = I18n::MessageFormat.format("Hello {name}!", name: "World")
        assert_equal "Hello World!", result
      end

      def test_plural_format
        result = I18n::MessageFormat.format(
          "{count, plural, one {# item} other {# items}}",
          count: 3
        )
        assert_equal "3 items", result
      end

      def test_caches_parsed_patterns
        pattern = "Hello {name}!"
        I18n::MessageFormat.format(pattern, name: "A")
        I18n::MessageFormat.format(pattern, name: "B")
        # No assertion on internals — just verify it works with caching
        assert_equal "Hello C!", I18n::MessageFormat.format(pattern, name: "C")
      end

      def test_format_with_locale
        result = I18n::MessageFormat.format("Hello {name}!", { name: "World" }, locale: :en)
        assert_equal "Hello World!", result
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/format_test.rb`
Expected: FAIL — `format` method not defined

**Step 3: Write minimal implementation**

Update `lib/i18n/message_format.rb`:

```ruby
# frozen_string_literal: true

require "i18n"
require_relative "message_format/version"
require_relative "message_format/nodes"
require_relative "message_format/parser"
require_relative "message_format/formatter"
require_relative "message_format/cache"

module I18n
  module MessageFormat
    class Error < StandardError; end

    @cache = Cache.new

    class << self
      def format(pattern, arguments = {}, locale: ::I18n.locale)
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
```

**Step 4: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/format_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "Add public API: I18n::MessageFormat.format with caching"
```

---

### Task 11: I18n Backend

**Files:**
- Create: `lib/i18n/message_format/backend.rb`
- Create: `test/i18n/message_format/backend_test.rb`
- Create: `test/fixtures/mf/en.yml`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Create the test fixture**

```yaml
# test/fixtures/mf/en.yml
en:
  greeting: "Hello {name}!"
  items: "{count, plural, one {# item} other {# items}}"
  welcome: "{gender, select, male {Welcome Mr. {name}} female {Welcome Ms. {name}} other {Welcome {name}}}"
```

**Step 2: Write the failing tests**

```ruby
# test/i18n/message_format/backend_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class BackendTest < Minitest::Test
      def setup
        @backend = Backend.new(File.expand_path("../../fixtures/mf/*.yml", __FILE__))
        @backend.load_translations
      end

      def test_translate_simple
        result = @backend.translate(:en, "greeting", name: "Alice")
        assert_equal "Hello Alice!", result
      end

      def test_translate_plural
        result = @backend.translate(:en, "items", count: 1)
        assert_equal "1 item", result
      end

      def test_translate_plural_other
        result = @backend.translate(:en, "items", count: 5)
        assert_equal "5 items", result
      end

      def test_translate_select
        result = @backend.translate(:en, "welcome", gender: "female", name: "Alice")
        assert_equal "Welcome Ms. Alice", result
      end

      def test_missing_key_returns_nil
        result = @backend.translate(:en, "nonexistent")
        assert_nil result
      end

      def test_chain_integration
        simple = ::I18n::Backend::Simple.new
        simple.store_translations(:en, { fallback: "from simple" })
        chain = ::I18n::Backend::Chain.new(@backend, simple)

        # Found in MF backend
        result = chain.translate(:en, "greeting", name: "Alice")
        assert_equal "Hello Alice!", result

        # Falls through to Simple backend
        result = chain.translate(:en, "fallback")
        assert_equal "from simple", result
      end

      def test_available_locales
        assert_includes @backend.available_locales, :en
      end
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/backend_test.rb`
Expected: FAIL — `Backend` not defined

**Step 4: Write minimal implementation**

```ruby
# lib/i18n/message_format/backend.rb
# frozen_string_literal: true

require "yaml"

module I18n
  module MessageFormat
    class Backend
      include ::I18n::Backend::Base

      def initialize(*glob_patterns)
        @glob_patterns = glob_patterns
        @translations = {}
        @cache = Cache.new
      end

      def load_translations
        @glob_patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            data = YAML.safe_load_file(file, permitted_classes: [Symbol])
            data.each do |locale, translations|
              store_translations(locale.to_sym, translations)
            end
          end
        end
      end

      def store_translations(locale, data, options = {})
        @translations[locale] ||= {}
        deep_merge!(@translations[locale], flatten_hash(data))
      end

      def translate(locale, key, options = {})
        pattern = lookup(locale, key)
        return nil if pattern.nil?
        return pattern unless pattern.is_a?(String)

        arguments = options.reject { |k, _| [:scope, :default, :separator].include?(k) }
        nodes = @cache.fetch(pattern) { Parser.new(pattern).parse }
        Formatter.new(nodes, arguments, locale).format
      end

      def available_locales
        @translations.keys
      end

      def initialized?
        !@translations.empty?
      end

      protected

      def lookup(locale, key, scope = [], options = {})
        keys = ::I18n.normalize_keys(locale, key, scope, options[:separator])
        keys.shift # remove locale

        result = @translations[locale]
        return nil unless result

        keys.each do |k|
          return nil unless result.is_a?(Hash)
          result = result[k] || result[k.to_s]
          return nil if result.nil?
        end

        result
      end

      private

      def flatten_hash(hash, prefix = nil)
        result = {}
        hash.each do |key, value|
          full_key = prefix ? :"#{prefix}.#{key}" : key.to_sym
          if value.is_a?(Hash)
            result.merge!(flatten_hash(value, full_key))
          else
            result[full_key] = value
          end
        end
        result
      end

      def deep_merge!(base, override)
        override.each do |key, value|
          base[key] = value
        end
        base
      end
    end
  end
end
```

**Step 5: Update the main require file**

Add `require_relative "message_format/backend"` to `lib/i18n/message_format.rb`.

**Step 6: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/backend_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add -A
git commit -m "Add I18n backend with Chain support"
```

---

### Task 12: Ordinal Plural Rules

**Files:**
- Create: `lib/i18n/message_format/ordinal_rules.rb`
- Create: `test/i18n/message_format/ordinal_rules_test.rb`
- Modify: `lib/i18n/message_format.rb`

**Step 1: Write the failing tests**

```ruby
# test/i18n/message_format/ordinal_rules_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class OrdinalRulesTest < Minitest::Test
      def setup
        ::I18n.backend = ::I18n::Backend::Simple.new
        OrdinalRules.install(:en)
      end

      def test_english_ordinal_1st
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :one, rule.call(1)
      end

      def test_english_ordinal_2nd
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :two, rule.call(2)
      end

      def test_english_ordinal_3rd
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :few, rule.call(3)
      end

      def test_english_ordinal_4th
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :other, rule.call(4)
      end

      def test_english_ordinal_11th
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :other, rule.call(11)
      end

      def test_english_ordinal_21st
        rule = ::I18n.t(:"i18n.ordinal.rule", locale: :en, resolve: false)
        assert_equal :one, rule.call(21)
      end

      def test_selectordinal_integration
        OrdinalRules.install(:en)
        result = I18n::MessageFormat.format(
          "{pos, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",
          pos: 3,
          locale: :en
        )
        assert_equal "3rd", result
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/ordinal_rules_test.rb`
Expected: FAIL — `OrdinalRules` not defined

**Step 3: Write minimal implementation**

```ruby
# lib/i18n/message_format/ordinal_rules.rb
# frozen_string_literal: true

module I18n
  module MessageFormat
    module OrdinalRules
      RULES = {
        en: lambda { |n|
          mod10 = n % 10
          mod100 = n % 100
          if mod10 == 1 && mod100 != 11
            :one
          elsif mod10 == 2 && mod100 != 12
            :two
          elsif mod10 == 3 && mod100 != 13
            :few
          else
            :other
          end
        }
      }.freeze

      def self.install(locale)
        rule = RULES[locale.to_sym]
        return unless rule

        ::I18n.backend.store_translations(locale, { i18n: { ordinal: { rule: rule } } })
      end

      def self.install_all
        RULES.each_key { |locale| install(locale) }
      end
    end
  end
end
```

**Step 4: Update the main require file**

Add `require_relative "message_format/ordinal_rules"` to `lib/i18n/message_format.rb`.

**Step 5: Run test to verify it passes**

Run: `bundle exec ruby -Itest -Ilib test/i18n/message_format/ordinal_rules_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "Add ordinal plural rules with English CLDR data"
```

---

### Task 13: End-to-End Integration Tests

**Files:**
- Create: `test/i18n/message_format/integration_test.rb`
- Create: `test/fixtures/mf/fr.yml`

**Step 1: Create French fixture**

```yaml
# test/fixtures/mf/fr.yml
fr:
  greeting: "Bonjour {name} !"
  items: "{count, plural, one {# article} other {# articles}}"
```

**Step 2: Write integration tests**

```ruby
# test/i18n/message_format/integration_test.rb
# frozen_string_literal: true

require "test_helper"

module I18n
  module MessageFormat
    class IntegrationTest < Minitest::Test
      def setup
        @simple = ::I18n::Backend::Simple.new
        @mf = Backend.new(File.expand_path("../../fixtures/mf/*.yml", __FILE__))
        ::I18n.backend = ::I18n::Backend::Chain.new(@mf, @simple)
        ::I18n.backend.load_translations

        @simple.store_translations(:en, { simple_key: "I am simple" })
        @simple.store_translations(:en, {
          date: { formats: { short: "%b %d", default: "%Y-%m-%d" } },
          time: { formats: { short: "%H:%M", default: "%Y-%m-%d %H:%M:%S" } }
        })

        # Install French plural rule
        @simple.store_translations(:fr, {
          i18n: {
            plural: {
              rule: lambda { |n| n >= 0 && n < 2 ? :one : :other }
            }
          }
        })
      end

      def test_mf_key_resolved
        assert_equal "Hello Alice!", ::I18n.t("greeting", name: "Alice")
      end

      def test_simple_key_falls_through
        assert_equal "I am simple", ::I18n.t("simple_key")
      end

      def test_plural_english
        assert_equal "1 item", ::I18n.t("items", count: 1)
        assert_equal "5 items", ::I18n.t("items", count: 5)
      end

      def test_plural_french
        assert_equal "1 article", ::I18n.t("items", count: 1, locale: :fr)
        assert_equal "5 articles", ::I18n.t("items", count: 5, locale: :fr)
      end

      def test_complex_nested_message
        pattern = "{gender, select, male {{count, plural, one {He has # item} other {He has # items}}} female {{count, plural, one {She has # item} other {She has # items}}} other {{count, plural, one {They have # item} other {They have # items}}}}"
        result = I18n::MessageFormat.format(pattern, gender: "female", count: 3)
        assert_equal "She has 3 items", result
      end

      def test_date_in_message
        pattern = "Updated on {d, date, short}"
        result = I18n::MessageFormat.format(pattern, d: Date.new(2026, 3, 15))
        assert_equal "Updated on Mar 15", result
      end

      def test_escaped_braces
        result = I18n::MessageFormat.format("Use '{ and '} for braces")
        assert_equal "Use { and } for braces", result
      end

      def test_escaped_single_quote
        result = I18n::MessageFormat.format("it''s {name}''s", name: "Alice")
        assert_equal "it's Alice's", result
      end
    end
  end
end
```

**Step 3: Run all tests**

Run: `bundle exec rake test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add -A
git commit -m "Add end-to-end integration tests"
```

---

### Task 14: Final Cleanup — Error Classes, README, Version

**Files:**
- Modify: `lib/i18n/message_format.rb` (ensure error classes are properly defined)
- Modify: `README.md`

**Step 1: Update README with real documentation**

```markdown
# I18n::MessageFormat

ICU Message Format support for the Ruby [i18n](https://github.com/ruby-i18n/i18n) gem. Pure Ruby parser, no native dependencies.

## Installation

```bash
bundle add i18n-message_format
```

## Usage

### Standalone

```ruby
require "i18n/message_format"

I18n::MessageFormat.format(
  "{name} has {count, plural, one {# item} other {# items}}",
  name: "Alice", count: 3
)
# => "Alice has 3 items"
```

### With I18n Backend

Store your Message Format strings in separate YAML files:

```yaml
# config/locales/mf/en.yml
en:
  greeting: "Hello {name}!"
  items: "{count, plural, one {# item} other {# items}}"
```

Configure the backend:

```ruby
I18n.backend = I18n::Backend::Chain.new(
  I18n::MessageFormat::Backend.new("config/locales/mf/*.yml"),
  I18n::Backend::Simple.new
)

I18n.t("greeting", name: "Alice")
# => "Hello Alice!"
```

### Supported Syntax

- Simple arguments: `{name}`
- Number format: `{count, number}`
- Date format: `{d, date, short}`
- Time format: `{t, time, short}`
- Plural: `{count, plural, one {# item} other {# items}}`
- Select: `{gender, select, male {He} female {She} other {They}}`
- Selectordinal: `{pos, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}`
- Nested messages
- Escaped braces: `'{ '} ''`

### Ordinal Rules

Install built-in ordinal rules for selectordinal support:

```ruby
I18n::MessageFormat::OrdinalRules.install(:en)
```

## License

MIT
```

**Step 2: Run all tests one final time**

Run: `bundle exec rake test`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add -A
git commit -m "Update README with usage documentation"
```
