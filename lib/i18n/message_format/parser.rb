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
            merged.last.value = +(merged.last.value) + node.value
          else
            merged << node
          end
        end
        merged
      end
    end
  end
end
